"""Validate staging transformations using temporary fixtures; never access a phone."""

import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import tempfile
import unittest
import xml.etree.ElementTree as ET


SCRIPT = Path(__file__).with_name("profile_phone.sh")
ANDROID = "http://schemas.android.com/apk/res/android"


class ProfilePreparationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="profile-script-fixtures-")
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.source = self.base / "fixture project"
        self.output = self.base / "result files"
        self.write("tool/profile_phone.sh", SCRIPT.read_text())
        self.write("pubspec.yaml", "name: fixture\n")
        self.write("pubspec.lock", "packages: {}\n")
        self.write("lib/main.dart", "void main() {}\n")
        self.write("integration_test/phone_performance_test.dart", "// fixture\n")
        self.write("test_driver/phone_performance.dart", "// fixture\n")
        self.write("ios/Runner.xcodeproj/project.pbxproj", "\n".join(
            "PRODUCT_BUNDLE_IDENTIFIER = com.original.app;\n"
            "DEVELOPMENT_TEAM = ORIGINAL12;\n"
            "INFOPLIST_KEY_CFBundleDisplayName = Original;"
            for _ in range(3)
        ))
        info = {"CFBundleIdentifier": "$(PRODUCT_BUNDLE_IDENTIFIER)",
                "CFBundleDisplayName": "Original"}
        self.write("ios/Runner/Info.plist", plistlib.dumps(info).decode())
        self.write("ios/Runner/Runner.entitlements", plistlib.dumps(
            {"com.apple.developer.applesignin": ["Default"]}
        ).decode())
        self.write("android/app/build.gradle.kts", 'namespace = "com.original.app"\n'
                   'applicationId = "com.original.app"\nminSdk = flutter.minSdkVersion\n')
        self.write("android/app/src/main/AndroidManifest.xml", f'<manifest xmlns:android="{ANDROID}">'
                   '<application android:label="Original" android:usesCleartextTraffic="false" />'
                   '</manifest>')
        self.write("android/app/src/profile/AndroidManifest.xml", f'<manifest xmlns:android="{ANDROID}">'
                   '<uses-permission android:name="android.permission.INTERNET" /></manifest>')
        for relative in ["build/file", ".dart_tool/file", "ios/Pods/file", "ios/.symlinks/file",
                         "android/.gradle/file", ".git", "ios/Flutter/Generated.xcconfig",
                         "android/key.properties", "android/upload.jks"]:
            self.write(relative, "must not be copied")
        self.env = dict(os.environ, TMPDIR=str(self.base), PERF_OUTPUT_DIR=str(self.output))
        self.env.pop("PERF_IOS_TEAM", None)
        # A fake Flutter executable fails if preparation ever invokes it.
        fake_bin = self.base / "bin"
        fake_bin.mkdir()
        fake_flutter = fake_bin / "flutter"
        fake_flutter.write_text(f'#!/bin/sh\ntouch "{self.base / "flutter-was-called"}"\nexit 97\n')
        fake_flutter.chmod(0o755)
        self.env["PATH"] = str(fake_bin) + os.pathsep + self.env["PATH"]

    def write(self, relative, text):
        path = self.source / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)

    def snapshot(self):
        return {str(path.relative_to(self.source)): path.read_bytes()
                for path in self.source.rglob("*") if path.is_file()}

    def prepare(self, platform, *extra, success=True):
        before = self.snapshot()
        result = subprocess.run(
            ["bash", str(self.source / "tool/profile_phone.sh"), platform,
             "fixture-device-only", "fixture-run", "--prepare-only", *extra],
            env=self.env, text=True, capture_output=True, check=False,
        )
        self.assertEqual(self.snapshot(), before, "Source project must never change")
        self.assertFalse((self.base / "flutter-was-called").exists())
        if not success:
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
            return result
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        metadata = json.loads((self.output / "fixture-run-preparation.json").read_text())
        stage = Path(metadata["stagePath"])
        self.assertTrue(stage.is_relative_to(self.base.resolve()))
        for relative in ["build", ".dart_tool", "ios/Pods", "ios/.symlinks", "android/.gradle",
                         ".git", "ios/Flutter/Generated.xcconfig", "android/key.properties", "android/upload.jks"]:
            self.assertFalse((stage / relative).exists(), relative)
        return stage, metadata

    def test_ios_identity_entitlements_network_and_optional_team_are_isolated(self):
        self.env["PERF_IOS_TEAM"] = "ABCDEFGHIJ"
        stage, metadata = self.prepare("ios")
        self.assertEqual(metadata["applicationId"], "com.bitiryemek.performance")
        project = (stage / "ios/Runner.xcodeproj/project.pbxproj").read_text()
        self.assertEqual(project.count("PRODUCT_BUNDLE_IDENTIFIER = com.bitiryemek.performance;"), 3)
        self.assertEqual(project.count("DEVELOPMENT_TEAM = ABCDEFGHIJ;"), 3)
        with (stage / "ios/Runner/Info.plist").open("rb") as stream:
            info = plistlib.load(stream)
        self.assertEqual(info["CFBundleDisplayName"], "Bitir Performans")
        self.assertEqual(info["NSAppTransportSecurity"], {"NSAllowsLocalNetworking": True})
        with (stage / "ios/Runner/Runner.entitlements").open("rb") as stream:
            self.assertEqual(plistlib.load(stream), {})

    def test_android_only_loopback_is_permitted_in_profile_overlay(self):
        stage, metadata = self.prepare("android")
        self.assertEqual(metadata["applicationId"], "com.original.app.performance")
        self.assertIn('namespace = "com.original.app"', (stage / "android/app/build.gradle.kts").read_text())
        main = ET.parse(stage / "android/app/src/main/AndroidManifest.xml").getroot().find("application")
        self.assertEqual(main.get(f"{{{ANDROID}}}usesCleartextTraffic"), "false")
        self.assertIsNone(main.get(f"{{{ANDROID}}}networkSecurityConfig"))
        config = ET.parse(stage / "android/app/src/profile/res/xml/phone_profile_network_security.xml").getroot()
        self.assertEqual(config.find("base-config").get("cleartextTrafficPermitted"), "false")
        self.assertEqual([node.text for node in config.findall("domain-config/domain")], ["127.0.0.1"])
        self.assertEqual(config.find("domain-config/domain").get("includeSubdomains"), "false")

    def test_copied_config_symlink_cannot_modify_source(self):
        config = self.source / "ios/Runner/Info.plist"
        outside = self.base / "outside.plist"
        shutil.copyfile(config, outside)
        before = outside.read_bytes()
        config.unlink()
        config.symlink_to(outside)
        result = self.prepare("ios", success=False)
        self.assertIn("escapes isolated staging", result.stderr)
        self.assertEqual(outside.read_bytes(), before)

    def test_binary_with_production_identifier_is_rejected(self):
        app = self.base / "Production.app"
        app.mkdir()
        with (app / "Info.plist").open("wb") as stream:
            plistlib.dump({"CFBundleIdentifier": "com.original.app"}, stream)
        result = self.prepare("ios", "--use-application-binary", str(app), success=False)
        self.assertIn("without the isolated performance bundle ID", result.stderr)

    def mocked_flutter(self, target_platform):
        calls = self.base / "mock-flutter-calls.jsonl"
        fake = self.base / "bin/flutter"
        fake.write_text('''#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
with Path(%r).open('a') as stream:
    stream.write(json.dumps({'args': sys.argv[1:], 'output': os.environ.get('PERF_OUTPUT_DIR'),
                             'run': os.environ.get('PERF_RUN_NAME')}) + '\\n')
if sys.argv[1] == 'devices':
    print(json.dumps([{'id': 'fixture-device-only', 'targetPlatform': %r, 'emulator': False}]))
''' % (str(calls), target_platform))
        fake.chmod(0o755)
        return calls

    def test_device_platform_mismatch_stops_before_build_or_install(self):
        calls = self.mocked_flutter("android-arm64")
        before = self.snapshot()
        result = subprocess.run(
            ["bash", str(self.source / "tool/profile_phone.sh"), "ios",
             "fixture-device-only", "mock-mismatch"],
            env=self.env, text=True, capture_output=True, check=False,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Device platform mismatch", result.stderr)
        invoked = [json.loads(line)["args"][0] for line in calls.read_text().splitlines()]
        self.assertEqual(invoked, ["devices"])
        self.assertEqual(self.snapshot(), before)

    def test_mocked_run_uses_profile_fixture_driver_and_result_environment(self):
        calls = self.mocked_flutter("ios")
        before = self.snapshot()
        result = subprocess.run(
            ["bash", str(self.source / "tool/profile_phone.sh"), "ios",
             "fixture-device-only", "mock-run"],
            env=self.env, text=True, capture_output=True, check=False,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        invoked = [json.loads(line) for line in calls.read_text().splitlines()]
        self.assertEqual([item["args"][0] for item in invoked], ["devices", "pub", "drive"])
        drive = invoked[-1]
        self.assertIn("--profile", drive["args"])
        self.assertIn("--publish-port", drive["args"])
        self.assertIn("integration_test/phone_performance_test.dart", drive["args"])
        self.assertIn("test_driver/phone_performance.dart", drive["args"])
        self.assertEqual(drive["run"], "mock-run")
        self.assertEqual(Path(drive["output"]), self.output.resolve())
        metadata = json.loads((self.output / "mock-run-preparation.json").read_text())
        self.assertFalse(Path(metadata["stagePath"]).exists(), "Successful staging should be removed")
        self.assertEqual(self.snapshot(), before)


if __name__ == "__main__":
    unittest.main(verbosity=2)
