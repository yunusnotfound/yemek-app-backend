/// Pickup dates/times belong to Turkey, independently of the device timezone.
/// Turkey uses UTC+03:00 for the current catalog's pickup dates.
DateTime? packagePickupEnd(Map<String, dynamic> package) {
  final date = package['pickupDate']?.toString();
  final end = _pickupTime(package['pickupEnd']);
  final start = _pickupTime(package['pickupStart']);
  if (date == null || date.length < 10 || end == null || start == null) {
    return null;
  }
  final day = DateTime.tryParse('${date.substring(0, 10)}T00:00:00Z');
  if (day == null ||
      day.toIso8601String().substring(0, 10) != date.substring(0, 10)) {
    return null;
  }
  return day
      .add(end)
      .add(end <= start ? const Duration(days: 1) : Duration.zero)
      .subtract(const Duration(hours: 3));
}

bool isPackageAvailable(Map<String, dynamic> package, {DateTime? now}) {
  final remaining = num.tryParse('${package['remainingQuantity']}') ?? 0;
  if (!_isTrue(package['isActive']) ||
      _isTrue(package['isSuspended']) ||
      remaining <= 0) {
    return false;
  }
  final end = packagePickupEnd(package);
  return end != null && end.isAfter(now ?? DateTime.now());
}

bool _isTrue(dynamic value) => value == true || value == 'true';

Duration? _pickupTime(dynamic value) {
  final match = RegExp(
    r'^(\d{2}):(\d{2})(?::(\d{2})(?:\.(\d{1,6}))?)?$',
  ).firstMatch(value?.toString() ?? '');
  if (match == null) return null;
  final hour = int.parse(match[1]!);
  final minute = int.parse(match[2]!);
  final second = int.parse(match[3] ?? '0');
  if (hour > 23 || minute > 59 || second > 59) return null;
  return Duration(
    hours: hour,
    minutes: minute,
    seconds: second,
    microseconds: int.parse((match[4] ?? '').padRight(6, '0')),
  );
}
