class OperatingHours {
  const OperatingHours._();

  static int? minutes(String? value) {
    if (value == null) return null;
    final parts = value.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return null;
    }
    return hour * 60 + minute;
  }

  static bool isOpenAt({
    required DateTime now,
    required String? openingTime,
    required String? closingTime,
  }) {
    final opening = minutes(openingTime);
    final closing = minutes(closingTime);
    if (opening == null || closing == null || opening >= closing) return false;
    final current = now.hour * 60 + now.minute;
    return current >= opening && current < closing;
  }

  static String display(String? value) {
    final total = minutes(value);
    if (total == null) return '--:--';
    final hour24 = total ~/ 60;
    final minute = total % 60;
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final suffix = hour24 < 12 ? 'AM' : 'PM';
    return '$hour12:${minute.toString().padLeft(2, '0')} $suffix';
  }
}
