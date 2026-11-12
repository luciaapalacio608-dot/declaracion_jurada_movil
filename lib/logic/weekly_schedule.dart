import 'package:declara_horario/domain/rules/overlap_detector.dart';
import 'package:declara_horario/domain/rules/schedule_slot.dart';
import 'package:declara_horario/domain/rules/time_rules.dart';
import 'package:declara_horario/models/models.dart';

/// One interval of the weekly schedule (R3): day, start, end and the
/// institution it belongs to.
class ScheduleEntry {
  const ScheduleEntry({
    required this.ownerId,
    required this.institution,
    required this.origin,
    required this.day,
    required this.startMinutes,
    required this.endMinutes,
    this.category,
    this.course,
  });

  /// Id of the appointment or additional institution that owns it.
  final String ownerId;

  /// Name shown to the person ("UCR · Sede del Sur", "Colegio X").
  final String institution;
  final SlotOrigin origin;
  final Weekday day;
  final int startMinutes;
  final int endMinutes;

  /// Only for the university appointment.
  final HourCategory? category;
  final String? course;

  /// Minutes of this interval (0 when the range is invalid).
  int get durationMinutes => TimeRules.isValidRange(startMinutes, endMinutes)
      ? TimeRules.durationMinutes(startMinutes, endMinutes)
      : 0;

  TimeBlock toBlock() => TimeBlock(
        day: day,
        startMinutes: startMinutes,
        endMinutes: endMinutes,
        category: origin == SlotOrigin.appointment ? category : null,
        course: origin == SlotOrigin.appointment ? course : null,
      );

  /// "08:00-12:00".
  String get rangeLabel =>
      '${TimeRules.format(startMinutes)}-${TimeRules.format(endMinutes)}';
}

/// Duration, total and the R4 checks of a weekly schedule. Pure Dart.
class WeeklySchedule {
  const WeeklySchedule._();

  static const OverlapDetector _detector = OverlapDetector();

  /// Total minutes of [entries].
  static int totalMinutes(List<ScheduleEntry> entries) =>
      entries.fold<int>(0, (total, e) => total + e.durationMinutes);

  /// Minutes per day, Monday to Saturday.
  static Map<Weekday, int> minutesByDay(List<ScheduleEntry> entries) => {
        for (final day in Weekday.values)
          day: totalMinutes(entries.where((e) => e.day == day).toList()),
      };

  /// R4: end after start, and no overlap on the same day even between
  /// different institutions. Uses DeclaraHorario's [OverlapDetector].
  static List<String> problems(
    List<ScheduleEntry> entries, {
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final problems = <String>[];
    for (final e in entries) {
      if (!TimeRules.isValidRange(e.startMinutes, e.endMinutes)) {
        problems.add('El ${e.day.label} ${e.rangeLabel} (${e.institution}): '
            'la hora de fin debe ser posterior a la de inicio.');
      }
    }
    final valid = [
      for (var i = 0; i < entries.length; i++)
        if (TimeRules.isValidRange(
            entries[i].startMinutes, entries[i].endMinutes))
          ScheduleSlot(
            itemId: '${entries[i].ownerId}#$i',
            label: entries[i].institution,
            origin: entries[i].origin,
            day: entries[i].day,
            startMinutes: entries[i].startMinutes,
            endMinutes: entries[i].endMinutes,
            startDate: startDate,
            endDate: endDate,
          ),
    ];
    problems.addAll(_detector.findConflicts(valid).map((i) => i.message));
    return problems;
  }
}
