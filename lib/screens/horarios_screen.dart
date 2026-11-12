import 'package:declara_horario/core/routing/app_routes.dart';
import 'package:declara_horario/domain/rules/appointment_defaults.dart';
import 'package:declara_horario/domain/rules/course_rules.dart';
import 'package:declara_horario/domain/rules/schedule_slot.dart';
import 'package:declara_horario/domain/rules/time_rules.dart';
import 'package:declara_horario/features/auth/state/auth_state.dart';
import 'package:declara_horario/features/declarations/state/declaration_state.dart';
import 'package:declara_horario/features/declarations/state/schedule_state.dart';
import 'package:declara_horario/models/models.dart';
import 'package:declara_horario/shared/widgets/app_components.dart';
import 'package:declara_horario/shared/widgets/error_view.dart';
import 'package:declara_horario/shared/widgets/loading_view.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app/lab_routes.dart';
import '../logic/weekly_schedule.dart';
import 'declaration_watch.dart';

/// R3/R4: weekly schedule, Monday to Saturday. Each interval has a day,
/// start, end and institution; the screen shows each duration, the total
/// and every conflict (end before start, overlaps on the same day even
/// between different institutions).
///
/// The intervals are saved as the blocks of DeclaraHorario's appointment
/// and external jobs, through [ScheduleState].
class HorariosScreen extends StatefulWidget {
  const HorariosScreen({super.key, required this.declarationId});

  final String declarationId;

  @override
  State<HorariosScreen> createState() => _HorariosScreenState();
}

class _HorariosScreenState extends State<HorariosScreen>
    with DeclarationWatch<HorariosScreen> {
  List<ScheduleEntry> _entries = <ScheduleEntry>[];
  Object? _loadedAppointments;
  Object? _loadedJobs;
  bool _dirty = false;
  bool _saving = false;

  @override
  String get watchedDeclarationId => widget.declarationId;

  /// Copies the saved blocks into the list, unless the person is editing.
  void _fill(ScheduleState schedule, DeclarantSnapshot snapshot) {
    if (_dirty) return;
    if (identical(_loadedAppointments, schedule.appointments) &&
        identical(_loadedJobs, schedule.externalJobs)) {
      return;
    }
    _loadedAppointments = schedule.appointments;
    _loadedJobs = schedule.externalJobs;
    _entries = [
      for (final a in schedule.appointments)
        for (final b in a.blocks)
          ScheduleEntry(
            ownerId: a.id,
            institution: a.workplace,
            origin: SlotOrigin.appointment,
            day: b.day,
            startMinutes: b.startMinutes,
            endMinutes: b.endMinutes,
            category: b.category,
            course: b.course,
          ),
      for (final j in schedule.externalJobs)
        for (final b in j.blocks)
          ScheduleEntry(
            ownerId: j.id,
            institution: j.institution,
            origin: SlotOrigin.externalJob,
            day: b.day,
            startMinutes: b.startMinutes,
            endMinutes: b.endMinutes,
          ),
    ];
  }

  Future<void> _add(ScheduleState schedule, WorkloadAssignment? assignment) async {
    final owners = <_Owner>[
      for (final a in schedule.appointments)
        _Owner(a.id, a.workplace, SlotOrigin.appointment),
      for (final j in schedule.externalJobs)
        _Owner(j.id, j.institution, SlotOrigin.externalJob),
    ];
    final courses = assignment == null
        ? const <String>[]
        : [for (final c in CourseRules.coursesOf(assignment)) c.name];
    final entry = await showModalBottomSheet<ScheduleEntry>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _IntervalSheet(owners: owners, courses: courses),
    );
    if (entry == null || !mounted) return;
    setState(() {
      _entries = [..._entries, entry];
      _dirty = true;
    });
  }

  Future<void> _save(Declaration declaration, ScheduleState schedule) async {
    final user = context.read<AuthState>().currentUser;
    final period = context.read<DeclarationState>().currentPeriod;
    final snapshot = schedule.version?.declarantSnapshot;
    if (user == null || period == null || snapshot == null) return;
    setState(() => _saving = true);
    final ref = VersionRef(
      declarationId: declaration.id,
      versionId: declaration.currentVersionId,
    );
    List<TimeBlock> blocksOf(String ownerId) => [
          for (final e in _entries)
            if (e.ownerId == ownerId) e.toBlock(),
        ];

    var ok = true;
    for (final a in schedule.appointments) {
      if (!ok) break;
      ok = await schedule.saveAppointment(
        ref: ref,
        actor: user,
        declarationStatus: declaration.status,
        appointment: AppointmentDefaults.apply(
          Appointment(
            id: a.id,
            workplace: a.workplace,
            position: a.position,
            workload: a.workload,
            startDate: a.startDate,
            endDate: a.endDate,
            blocks: blocksOf(a.id),
            projects: a.projects,
          ),
          snapshot: snapshot,
          period: period,
        ),
      );
    }
    for (final j in schedule.externalJobs) {
      if (!ok) break;
      ok = await schedule.saveExternalJob(
        ref: ref,
        actor: user,
        declarationStatus: declaration.status,
        externalJob: ExternalJob(
          id: j.id,
          institution: j.institution,
          institutionType: j.institutionType,
          position: j.position,
          workload: j.workload,
          weeklyMinutes: j.weeklyMinutes,
          startDate: j.startDate,
          endDate: j.endDate,
          blocks: blocksOf(j.id),
        ),
      );
    }
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (ok) {
        _dirty = false;
        _loadedAppointments = null;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? 'Horario guardado.'
          : schedule.errorMessage ?? 'No se pudo guardar. Intente de nuevo.'),
    ));
  }

  Future<bool> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cambios sin guardar'),
        content: const Text('Si sale ahora, se pierden los cambios.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Seguir editando'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Salir sin guardar'),
          ),
        ],
      ),
    );
    return leave ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final declarations = context.watch<DeclarationState>();
    final schedule = context.watch<ScheduleState>();
    final declaration = watchedDeclaration(declarations);
    final period = declarations.currentPeriod;
    final snapshot = schedule.version?.declarantSnapshot;

    if (declaration == null || period == null || snapshot == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Horario semanal')),
        body: declarations.errorMessage != null && !declarations.isLoading
            ? ErrorView(message: declarations.errorMessage!)
            : const LoadingView(),
      );
    }
    _fill(schedule, snapshot);

    final editable = declaration.status == DeclarationStatus.borrador ||
        declaration.status == DeclarationStatus.validada;
    final problems = WeeklySchedule.problems(
      _entries,
      startDate: period.startDate,
      endDate: period.endDate,
    );
    final total = WeeklySchedule.totalMinutes(_entries);
    final byDay = WeeklySchedule.minutesByDay(_entries);
    final theme = Theme.of(context);

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _confirmLeave()) {
          setState(() => _dirty = false);
          navigator.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Horario semanal'),
          actions: [
            IconButton(
              tooltip: 'Ver resumen',
              icon: const Icon(Icons.fact_check_outlined),
              onPressed: () =>
                  context.push(LabRoutes.summaryPath(declaration.id)),
            ),
          ],
        ),
        floatingActionButton: editable && schedule.appointments.isNotEmpty
            ? FloatingActionButton.extended(
                key: const ValueKey<String>('add-interval'),
                onPressed: () => _add(schedule, declarations.currentAssignment),
                icon: const Icon(Icons.add),
                label: const Text('Agregar intervalo'),
              )
            : null,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            children: [
              InfoCard(
                child: Row(
                  children: [
                    const IconBadge(icon: Icons.schedule_outlined),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Total semanal',
                              style: theme.textTheme.labelLarge),
                          Text(TimeRules.hoursLabel(total),
                              key: const ValueKey<String>('total-hours'),
                              style: theme.textTheme.headlineSmall),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (schedule.appointments.isEmpty) ...[
                const InlineBanner(
                  tone: BannerTone.info,
                  message: 'Primero guarde los datos de la declaración '
                      '(puesto y jornada).',
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => context
                      .push(AppRoutes.declarationEditPath(declaration.id)),
                  child: const Text('Ir al formulario'),
                ),
              ],
              if (problems.isNotEmpty)
                InlineBanner(
                  key: const ValueKey<String>('schedule-problems'),
                  message: 'Conflictos en el horario (no se podrá validar):\n• '
                      '${problems.join('\n• ')}',
                )
              else if (_entries.isNotEmpty)
                const InlineBanner(
                  tone: BannerTone.info,
                  message: 'Sin choques de horario.',
                ),
              const SizedBox(height: 12),
              for (final day in Weekday.values)
                _dayCard(day, byDay[day] ?? 0, editable),
            ],
          ),
        ),
        bottomNavigationBar: !editable || schedule.appointments.isEmpty
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: FilledButton.icon(
                    key: const ValueKey<String>('save-schedule'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    onPressed: _saving || !_dirty
                        ? null
                        : () => _save(declaration, schedule),
                    icon: const Icon(Icons.save_outlined),
                    label: Text(_dirty ? 'Guardar horario' : 'Horario guardado'),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _dayCard(Weekday day, int minutes, bool editable) {
    final theme = Theme.of(context);
    final items = [
      for (var i = 0; i < _entries.length; i++)
        if (_entries[i].day == day) i,
    ]..sort((a, b) =>
        _entries[a].startMinutes.compareTo(_entries[b].startMinutes));
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InfoCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                    child: Text(day.title, style: theme.textTheme.titleMedium)),
                Text(TimeRules.hoursLabel(minutes),
                    style: theme.textTheme.labelLarge),
              ],
            ),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Sin intervalos',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
              ),
            for (final i in items)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                    '${_entries[i].rangeLabel} · '
                    '${TimeRules.hoursLabel(_entries[i].durationMinutes)}'),
                subtitle: Text([
                  _entries[i].institution,
                  if (_entries[i].category != null)
                    _entries[i].category!.shortTitle,
                ].join(' · ')),
                trailing: editable
                    ? IconButton(
                        tooltip: 'Quitar intervalo',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => setState(() {
                          _entries = [..._entries]..removeAt(i);
                          _dirty = true;
                        }),
                      )
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}

class _Owner {
  const _Owner(this.id, this.name, this.origin);
  final String id;
  final String name;
  final SlotOrigin origin;
}

/// Bottom sheet to add one interval: day, start, end and institution.
class _IntervalSheet extends StatefulWidget {
  const _IntervalSheet({required this.owners, required this.courses});

  final List<_Owner> owners;
  final List<String> courses;

  @override
  State<_IntervalSheet> createState() => _IntervalSheetState();
}

class _IntervalSheetState extends State<_IntervalSheet> {
  Weekday _day = Weekday.monday;
  int _start = 8 * 60;
  int _end = 10 * 60;
  late _Owner _owner = widget.owners.first;
  HourCategory _category = HourCategory.lesson;
  String? _error;

  Future<void> _pick(bool start) async {
    final current = start ? _start : _end;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      final minutes = picked.hour * 60 + picked.minute;
      if (start) {
        _start = minutes;
      } else {
        _end = minutes;
      }
      _error = null;
    });
  }

  void _accept() {
    if (!TimeRules.isValidRange(_start, _end)) {
      setState(() =>
          _error = 'La hora de fin debe ser posterior a la de inicio.');
      return;
    }
    final appointment = _owner.origin == SlotOrigin.appointment;
    Navigator.of(context).pop(ScheduleEntry(
      ownerId: _owner.id,
      institution: _owner.name,
      origin: _owner.origin,
      day: _day,
      startMinutes: _start,
      endMinutes: _end,
      category: appointment ? _category : null,
      course: appointment &&
              _category == HourCategory.lesson &&
              widget.courses.isNotEmpty
          ? widget.courses.first
          : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 0, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Nuevo intervalo', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            DropdownButtonFormField<Weekday>(
              initialValue: _day,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Día'),
              items: [
                for (final d in Weekday.values)
                  DropdownMenuItem(value: d, child: Text(d.title)),
              ],
              onChanged: (v) => setState(() => _day = v ?? _day),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52)),
                    onPressed: () => _pick(true),
                    icon: const Icon(Icons.login),
                    label: Text('Inicio ${TimeRules.format(_start)}'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52)),
                    onPressed: () => _pick(false),
                    icon: const Icon(Icons.logout),
                    label: Text('Fin ${TimeRules.format(_end)}'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              TimeRules.isValidRange(_start, _end)
                  ? 'Duración: ${TimeRules.hoursLabel(TimeRules.durationMinutes(_start, _end))}'
                  : 'Duración: —',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<_Owner>(
              initialValue: _owner,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Institución'),
              items: [
                for (final o in widget.owners)
                  DropdownMenuItem(
                      value: o,
                      child: Text(o.name, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) => setState(() => _owner = v ?? _owner),
            ),
            if (_owner.origin == SlotOrigin.appointment) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<HourCategory>(
                initialValue: _category,
                isExpanded: true,
                decoration:
                    const InputDecoration(labelText: 'Tipo de actividad'),
                items: [
                  for (final c in HourCategory.values)
                    DropdownMenuItem(value: c, child: Text(c.shortTitle)),
                ],
                onChanged: (v) => setState(() => _category = v ?? _category),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              InlineBanner(message: _error!),
            ],
            const SizedBox(height: 16),
            FilledButton(
              key: const ValueKey<String>('accept-interval'),
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52)),
              onPressed: _accept,
              child: const Text('Agregar'),
            ),
          ],
        ),
      ),
    );
  }
}
