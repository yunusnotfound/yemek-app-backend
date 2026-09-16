#!/usr/bin/env bash
# Run only the isolated fixture app; never edit or install the production app.
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: tool/profile_phone.sh ios|android DEVICE_ID RUN_NAME [OPTIONS]

Options:
  --prepare-only                   Prepare and retain the isolated copy; do not
                                   invoke Flutter or communicate with a device.
  --use-application-binary APP      iOS only: reuse a previously signed profile
                                   Runner.app with the performance bundle ID.
  --help                           Show this help.

Environment:
  PERF_OUTPUT_DIR   Result/log directory (default: ../output/phone-performance).
  PERF_IOS_TEAM     Optional 10-character Apple team ID, applied only to staging.
  PERF_KEEP_STAGE=1 Retain staging after success (failure always retains it).
USAGE
}

fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }

if [[ "${1:-}" == '--help' || "${1:-}" == '-h' ]]; then usage; exit 0; fi
[[ $# -ge 3 ]] || { usage >&2; exit 2; }
profile_platform="$1"
profile_device="$2"
profile_run="$3"
shift 3
case "$profile_platform" in ios|android) ;; *) fail 'Platform must be ios or android.' ;; esac
[[ -n "$profile_device" ]] || fail 'Provide an explicit physical device ID.'
[[ "$profile_run" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || fail 'RUN_NAME must be a filename component using letters, numbers, dots, dashes or underscores.'

profile_prepare_only=0
profile_binary=''
while [[ $# -gt 0 ]]; do
  case "$1" in
    --prepare-only) profile_prepare_only=1; shift ;;
    --use-application-binary)
      [[ $# -ge 2 ]] || fail '--use-application-binary requires a path.'
      profile_binary="$2"; shift 2 ;;
    --help) usage; exit 0 ;;
    *) fail "Unknown option: $1" ;;
  esac
done
[[ -z "$profile_binary" || "$profile_platform" == 'ios' ]] || fail 'The binary fallback accepts an iOS Runner.app only.'
for profile_command in rsync python3; do
  command -v "$profile_command" >/dev/null || fail "Required command not found: $profile_command"
done
if [[ "$profile_prepare_only" == 0 ]]; then
  command -v flutter >/dev/null || fail 'Flutter must be on PATH.'
fi

profile_tool_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
profile_source="$(cd "$profile_tool_dir/.." && pwd -P)"
profile_output="${PERF_OUTPUT_DIR:-$profile_source/../output/phone-performance}"
mkdir -p "$profile_output"
profile_output="$(cd "$profile_output" && pwd -P)"
profile_stage="$(mktemp -d "${TMPDIR:-/tmp}/bitir-phone-profile.XXXXXX")"

cleanup() {
  local profile_status=$?
  if [[ "$profile_prepare_only" == 1 || "${PERF_KEEP_STAGE:-0}" == 1 || "$profile_status" != 0 ]]; then
    printf '\nIsolated staging retained: %s\n' "$profile_stage"
  else
    rm -rf -- "$profile_stage"
  fi
}
trap cleanup EXIT

# Exclude generated paths and stale absolute Flutter build settings. Preserve
# the current working tree, including uncommitted product and test changes.
rsync -a \
  --exclude='build/' --exclude='.dart_tool/' --exclude='Pods/' \
  --exclude='.symlinks/' --exclude='.gradle/' --exclude='.git' \
  --exclude='.flutter-plugins' --exclude='.flutter-plugins-dependencies' \
  --exclude='/ios/Flutter/Generated.xcconfig' \
  --exclude='/ios/Flutter/flutter_export_environment.sh' \
  --exclude='/ios/Flutter/ephemeral/' --exclude='/output/' \
  --exclude='/android/key.properties' --exclude='*.jks' --exclude='*.keystore' \
  "$profile_source/" "$profile_stage/"

python3 - "$profile_stage" "$profile_platform" "$profile_output" "$profile_run" "${PERF_IOS_TEAM:-}" "$profile_binary" <<'PY'
import datetime
import hashlib
import json
from pathlib import Path
import plistlib
import re
import sys
import xml.etree.ElementTree as ET

stage = Path(sys.argv[1]).resolve()
platform, output, run_name, team, binary = sys.argv[2:]
android_ns = 'http://schemas.android.com/apk/res/android'
ET.register_namespace('android', android_ns)

def file(relative):
    path = stage / relative
    # Never follow a copied configuration symlink back into the source tree.
    if not path.resolve().is_relative_to(stage):
        raise SystemExit(f'Configuration escapes isolated staging: {relative}')
    return path

if platform == 'ios':
    app_id = 'com.bitiryemek.performance'
    project = file('ios/Runner.xcodeproj/project.pbxproj')
    text = project.read_text()
    def bundle_id(match):
        suffix = '.RunnerTests' if match[1].strip('"').endswith('.RunnerTests') else ''
        return f'PRODUCT_BUNDLE_IDENTIFIER = {app_id}{suffix};'
    text, replaced = re.subn(r'PRODUCT_BUNDLE_IDENTIFIER\s*=\s*([^;]+);', bundle_id, text)
    if replaced < 3:
        raise SystemExit('Expected iOS Runner bundle IDs were not found; refusing to run.')
    text = re.sub(r'INFOPLIST_KEY_CFBundleDisplayName\s*=\s*[^;]+;', 'INFOPLIST_KEY_CFBundleDisplayName = "Bitir Performans";', text)
    if team:
        if not re.fullmatch(r'[A-Z0-9]{10}', team):
            raise SystemExit('PERF_IOS_TEAM must be a 10-character Apple team ID.')
        text, count = re.subn(r'DEVELOPMENT_TEAM\s*=\s*[^;]+;', f'DEVELOPMENT_TEAM = {team};', text)
        if not count:
            raise SystemExit('No DEVELOPMENT_TEAM setting was found in staging.')
    project.write_text(text)
    info_path = file('ios/Runner/Info.plist')
    with info_path.open('rb') as stream:
        info = plistlib.load(stream)
    info['CFBundleDisplayName'] = 'Bitir Performans'
    info['NSAppTransportSecurity'] = {'NSAllowsLocalNetworking': True}
    info['NSLocalNetworkUsageDescription'] = 'Performans testi telefon ile geliştirme bilgisayarı arasında yerel bağlantı kurar.'
    info['NSBonjourServices'] = ['_dartVmService._tcp']
    with info_path.open('wb') as stream:
        plistlib.dump(info, stream)
    with file('ios/Runner/Runner.entitlements').open('wb') as stream:
        plistlib.dump({}, stream)
    if binary:
        app = Path(binary).expanduser().resolve()
        if app.suffix != '.app' or not (app / 'Info.plist').is_file():
            raise SystemExit('Binary fallback must point to a built iOS .app directory.')
        with (app / 'Info.plist').open('rb') as stream:
            binary_info = plistlib.load(stream)
        if binary_info.get('CFBundleIdentifier') != app_id:
            raise SystemExit('Refusing a binary without the isolated performance bundle ID.')
else:
    project = file('android/app/build.gradle.kts')
    text = project.read_text()
    match = re.search(r'applicationId\s*=\s*"([^"]+)"', text)
    if not match:
        raise SystemExit('Expected Android applicationId was not found; refusing to run.')
    app_id = match[1] + '.performance'
    text = text[:match.start()] + f'applicationId = "{app_id}"' + text[match.end():]
    project.write_text(text)
    manifest_path = file('android/app/src/main/AndroidManifest.xml')
    manifest = ET.parse(manifest_path)
    application = manifest.getroot().find('application')
    if application is None or application.get(f'{{{android_ns}}}usesCleartextTraffic') != 'false':
        raise SystemExit('Expected production cleartext=false guard was not found.')
    application.set(f'{{{android_ns}}}label', 'Bitir Performans')
    manifest.write(manifest_path, encoding='unicode')
    # Android 7+ honors a network-security config over usesCleartextTraffic.
    # Only this staging profile overlay permits the fixture's loopback address.
    profile_path = file('android/app/src/profile/AndroidManifest.xml')
    profile = ET.parse(profile_path)
    application = profile.getroot().find('application')
    if application is None:
        application = ET.SubElement(profile.getroot(), 'application')
    application.set(f'{{{android_ns}}}networkSecurityConfig', '@xml/phone_profile_network_security')
    profile.write(profile_path, encoding='unicode')
    config = file('android/app/src/profile/res/xml/phone_profile_network_security.xml')
    config.parent.mkdir(parents=True, exist_ok=True)
    config.write_text('''<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <base-config cleartextTrafficPermitted="false" />
    <domain-config cleartextTrafficPermitted="true">
        <domain includeSubdomains="false">127.0.0.1</domain>
    </domain-config>
</network-security-config>
''')

fingerprint = hashlib.sha256()
for relative in ['lib', 'assets', 'integration_test', 'test_driver', 'pubspec.yaml', 'pubspec.lock']:
    path = stage / relative
    files = sorted(path.rglob('*')) if path.is_dir() else [path]
    for source in files:
        if source.is_file():
            fingerprint.update(str(source.relative_to(stage)).encode())
            fingerprint.update(b'\0')
            fingerprint.update(source.read_bytes())
metadata = {
    'preparedAtUtc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
    'platform': platform,
    'runName': run_name,
    'applicationId': app_id,
    'stagePath': str(stage),
    'sourceSnapshotSha256': fingerprint.hexdigest(),
    'applicationBinary': str(Path(binary).expanduser().resolve()) if binary else None,
}
Path(output, f'{run_name}-preparation.json').write_text(json.dumps(metadata, indent=2) + '\n')
print(f'Isolated application: {app_id}')
PY

printf 'Result directory: %s\n' "$profile_output"
if [[ "$profile_prepare_only" == 1 ]]; then
  printf 'Preparation only: Flutter and the phone were not accessed.\n'
  exit 0
fi

profile_args=(drive --profile --no-pub --device-id "$profile_device"
  --driver test_driver/phone_performance.dart
  --target integration_test/phone_performance_test.dart)
if [[ "$profile_platform" == 'ios' ]]; then profile_args+=(--publish-port); fi
if [[ -n "$profile_binary" ]]; then
  profile_binary="$(python3 -c 'from pathlib import Path; import sys; print(Path(sys.argv[1]).expanduser().resolve())' "$profile_binary")"
  profile_args+=(--use-application-binary "$profile_binary")
fi
cd "$profile_stage"
# An accidentally supplied Android ID must never select the untouched iOS
# copy's Android application, or vice versa. Only an exact physical ID passes.
flutter devices --machine > "$profile_output/$profile_run-devices.json"
python3 - "$profile_output/$profile_run-devices.json" "$profile_device" "$profile_platform" <<'PY'
import json
import sys
with open(sys.argv[1]) as stream:
    matches = [device for device in json.load(stream) if device.get('id') == sys.argv[2]]
if len(matches) != 1:
    raise SystemExit('Provide the exact connected physical device ID from flutter devices.')
device = matches[0]
platform = device.get('targetPlatform', '')
expected = platform == 'ios' if sys.argv[3] == 'ios' else platform.startswith('android-')
if not expected or device.get('emulator', False):
    raise SystemExit('Device platform mismatch or emulator selected; physical profile run refused.')
PY
flutter pub get 2>&1 | tee "$profile_output/$profile_run-pub-get.log"
PERF_OUTPUT_DIR="$profile_output" PERF_RUN_NAME="$profile_run" \
  flutter "${profile_args[@]}" 2>&1 | tee "$profile_output/$profile_run-drive.log"
