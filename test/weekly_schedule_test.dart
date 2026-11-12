import 'package:declara_horario/domain/rules/schedule_slot.dart';
import 'package:declara_horario/models/weekday.dart';
import 'package:declaracion_jurada_movil/logic/weekly_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

// Fictitious data only.
final _start = DateTime(2026, 8, 3);
final _end = DateTime(2026, 12, 12);

ScheduleEntry _entry(String owner, SlotOrigin origin, Weekday day, int from,
        int to) =>
    ScheduleEntry(
      ownerId: owner,
      institution: owner,
      origin: origin,
      day: day,
      startMinutes: from * 60,
      endMinutes: to * 60,
    );

void main() {
  group('Weekly schedule (R3/R4)', () {
    test('Test 02 (mandatory case): Monday 8-12 and 11-14 is a conflict', () {
      final entries = [
        _entry('UCR', SlotOrigin.appointment, Weekday.monday, 8, 12),
        _entry('Colegio Ficticio', SlotOrigin.externalJob, Weekday.monday,
            11, 14),
      ];
      final problems =
          WeeklySchedule.problems(entries, startDate: _start, endDate: _end);
      expect(problems, hasLength(1));
      expect(problems.single, contains('lunes'));
      expect(problems.single, contains('11:00'));
    });

    test('overlap inside the same institution is also a conflict', () {
      final entries = [
        _entry('UCR', SlotOrigin.appointment, Weekday.monday, 8, 12),
        _entry('UCR', SlotOrigin.appointment, Weekday.monday, 11, 14),
      ];
      expect(
          WeeklySchedule.problems(entries, startDate: _start, endDate: _end),
          hasLength(1));
    });

    test('adjacent intervals and other days do not conflict', () {
      final entries = [
        _entry('UCR', SlotOrigin.appointment, Weekday.monday, 8, 12),
        _entry('UCR', SlotOrigin.appointment, Weekday.monday, 12, 14),
        _entry('UCR', SlotOrigin.appointment, Weekday.tuesday, 11, 14),
      ];
      expect(
          WeeklySchedule.problems(entries, startDate: _start, endDate: _end),
          isEmpty);
    });

    test('end before start is reported', () {
      final entries = [
        _entry('UCR', SlotOrigin.appointment, Weekday.friday, 14, 10),
      ];
      final problems =
          WeeklySchedule.problems(entries, startDate: _start, endDate: _end);
      expect(problems.single, contains('posterior'));
    });

    test('duration of each interval and weekly total', () {
      final entries = [
        _entry('UCR', SlotOrigin.appointment, Weekday.monday, 8, 12),
        _entry('UCR', SlotOrigin.appointment, Weekday.saturday, 9, 11),
      ];
      expect(entries.first.durationMinutes, 240);
      expect(WeeklySchedule.totalMinutes(entries), 360);
      expect(WeeklySchedule.minutesByDay(entries)[Weekday.saturday], 120);
    });
  });
}
