class WeeklyDeliverySlot {
  const WeeklyDeliverySlot({
    required this.id,
    required this.weekday,
    required this.startMinute,
    required this.endMinute,
    required this.capacity,
    this.active = true,
  });

  final String id;

  /// ISO weekday: Monday = 1, Sunday = 7.
  final int weekday;
  final int startMinute;
  final int endMinute;
  final int capacity;
  final bool active;

  factory WeeklyDeliverySlot.fromMap(Map<String, dynamic> map) {
    return WeeklyDeliverySlot(
      id: map['id'] as String? ?? '',
      weekday: (map['weekday'] as num?)?.toInt() ?? 1,
      startMinute: (map['start_minute'] as num?)?.toInt() ?? 600,
      endMinute: (map['end_minute'] as num?)?.toInt() ?? 720,
      capacity: (map['capacity'] as num?)?.toInt() ?? 1,
      active: map['active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'weekday': weekday,
    'start_minute': startMinute,
    'end_minute': endMinute,
    'capacity': capacity,
    'active': active,
  };

  String get timeLabel =>
      '${_formatMinute(startMinute)} – ${_formatMinute(endMinute)}';

  static String _formatMinute(int minute) =>
      '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';
}

class DeliveryScheduleSettings {
  const DeliveryScheduleSettings({
    this.enabled = false,
    this.minimumNoticeHours = 24,
    this.slots = const [],
    this.closedDates = const [],
  });

  final bool enabled;
  final int minimumNoticeHours;
  final List<WeeklyDeliverySlot> slots;

  /// One-off closures in YYYY-MM-DD form, in the workshop's calendar.
  final List<String> closedDates;

  factory DeliveryScheduleSettings.fromMap(Map<String, dynamic> map) {
    final rawSlots = map['slots'] as List<dynamic>? ?? const [];
    final rawClosedDates = map['closed_dates'] as List<dynamic>? ?? const [];

    return DeliveryScheduleSettings(
      enabled: map['enabled'] as bool? ?? false,
      minimumNoticeHours: (map['minimum_notice_hours'] as num?)?.toInt() ?? 24,
      slots: rawSlots
          .whereType<Map>()
          .map(
            (slot) =>
                WeeklyDeliverySlot.fromMap(Map<String, dynamic>.from(slot)),
          )
          .toList(),
      closedDates: rawClosedDates.whereType<String>().toList(),
    );
  }

  Map<String, dynamic> toMap() => {
    'enabled': enabled,
    'minimum_notice_hours': minimumNoticeHours,
    'maximum_days_ahead': 90,
    'slots': slots.map((slot) => slot.toMap()).toList(),
    'closed_dates': closedDates,
  };
}

class AvailableDeliverySlot {
  const AvailableDeliverySlot({
    required this.id,
    required this.dateKey,
    required this.timeLabel,
    required this.startAt,
    required this.endAt,
    required this.remainingCapacity,
  });

  final String id;
  final String dateKey;
  final String timeLabel;
  final DateTime startAt;
  final DateTime endAt;
  final int remainingCapacity;

  factory AvailableDeliverySlot.fromMap(Map<String, dynamic> map) {
    return AvailableDeliverySlot(
      id: map['id'] as String,
      dateKey: map['date'] as String,
      timeLabel: map['time_label'] as String,
      startAt: DateTime.parse(map['start_at'] as String).toUtc(),
      endAt: DateTime.parse(map['end_at'] as String).toUtc(),
      remainingCapacity: (map['remaining_capacity'] as num).toInt(),
    );
  }

  String get dateLabel {
    final parts = dateKey.split('-').map(int.parse).toList();
    final date = DateTime.utc(parts[0], parts[1], parts[2]);
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

class DeliveryAvailability {
  const DeliveryAvailability({required this.enabled, required this.slots});

  final bool enabled;
  final List<AvailableDeliverySlot> slots;
}

class DeliverySlotReconciliationResult {
  const DeliverySlotReconciliationResult({
    required this.dateKey,
    required this.checkedSlots,
    required this.changedSlots,
    required this.previousReservations,
    required this.correctedReservations,
  });

  final String dateKey;
  final int checkedSlots;
  final int changedSlots;
  final int previousReservations;
  final int correctedReservations;

  factory DeliverySlotReconciliationResult.fromMap(Map<String, dynamic> map) =>
      DeliverySlotReconciliationResult(
        dateKey: map['date'] as String? ?? '',
        checkedSlots: (map['checked_slots'] as num?)?.toInt() ?? 0,
        changedSlots: (map['changed_slots'] as num?)?.toInt() ?? 0,
        previousReservations:
            (map['previous_reservations'] as num?)?.toInt() ?? 0,
        correctedReservations:
            (map['corrected_reservations'] as num?)?.toInt() ?? 0,
      );
}

String deliveryDateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
