import 'package:declara_horario/core/routing/app_routes.dart';
import 'package:declara_horario/domain/rules/schedule_slot.dart';
import 'package:declara_horario/domain/rules/time_rules.dart';
import 'package:declara_horario/features/auth/state/auth_state.dart';
import 'package:declara_horario/features/declarations/state/declaration_state.dart';
import 'package:declara_horario/features/declarations/state/schedule_state.dart';
import 'package:declara_horario/features/validation/state/validation_state.dart';
import 'package:declara_horario/models/models.dart';
import 'package:declara_horario/shared/widgets/app_components.dart';
import 'package:declara_horario/shared/widgets/error_view.dart';
import 'package:declara_horario/shared/widgets/loading_view.dart';
import 'package:declara_horario/shared/widgets/status_chip.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app/lab_routes.dart';
import '../logic/declaration_form.dart';
import '../logic/weekly_schedule.dart';
import 'declaration_watch.dart';

/// R6: summary of a declaration — data, schedule, total hours, validation
/// result and status — with buttons to correct the data or the schedule.
///
/// The validation is DeclaraHorario's [ValidationState] (ScheduleValidator:
/// overlaps, workday, lessons…). "Validar" moves the declaration to
/// VALIDADA only when there are no blocking problems.
class ResumenScreen extends StatefulWidget {
  const ResumenScreen({super.key, required this.declarationId});

  final String declarationId;

  @override
  State<ResumenScreen> createState() => _ResumenScreenState();
}

class _ResumenScreenState extends State<ResumenScreen>
    with DeclarationWatch<ResumenScreen> {
  bool _validating = false;
  Object? _validatedVersion;

  @override
  String get watchedDeclarationId => widget.declarationId;

  /// Runs DeclaraHorario's validation on what is saved in Firestore.
  void _runValidation(ScheduleState schedule) {
    if (identical(_validatedVersion, schedule.appointments) ||
        schedule.version == null) {
      return;
    }
    _validatedVersion = schedule.appointments;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ValidationState>().load(widget.declarationId);
    });
  }

  Future<void> _validate(Declaration declaration) async {
    final user = context.read<AuthState>().currentUser;
    if (user == null) return;
    setState(() => _validating = true);
    final validation = context.read<ValidationState>();
    final ok = await validation.confirmValidation(
      declarationId: declaration.id,
      actor: user,
    );
    if (!mounted) return;
    setState(() => _validating = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? 'Declaración VALIDADA.'
          : validation.errorMessage ?? 'No se pudo validar.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final declarations = context.watch<DeclarationState>();
    final schedule = context.watch<ScheduleState>();
    final validation = context.watch<ValidationState>();
    final declaration = watchedDeclaration(declarations);
    final period = declarations.currentPeriod;
    final version = schedule.version;

    if (declaration == null || period == null || version == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Resumen')),
        body: declarations.errorMessage != null && !declarations.isLoading
            ? ErrorView(message: declarations.errorMessage!)
            : const LoadingView(),
      );
    }
    _runValidation(schedule);

    final snapshot = version.declarantSnapshot;
    final appointment =
        schedule.appointments.isEmpty ? null : schedule.appointments.first;
    final entries = <ScheduleEntry>[
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
    ]..sort((a, b) => a.day.number != b.day.number
        ? a.day.number.compareTo(b.day.number)
        : a.startMinutes.compareTo(b.startMinutes));
    final scheduleProblems = WeeklySchedule.problems(
      entries,
      startDate: period.startDate,
      endDate: period.endDate,
    );
    final result = validation.result;
    final blocking = [
      ...scheduleProblems,
      if (result != null)
        for (final issue in result.issues)
          if (issue.severity == ValidationSeverity.blocking &&
              !scheduleProblems.contains(issue.message))
            issue.message,
    ];
    final warnings = [
      if (result != null)
        for (final issue in result.issues)
          if (issue.severity != ValidationSeverity.blocking) issue.message,
    ];
    final canValidate = declaration.status == DeclarationStatus.borrador &&
        result != null &&
        blocking.isEmpty &&
        appointment != null;
    final theme = Theme.of(context);

    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant)),
              Text(value.isEmpty ? '—' : value,
                  style: theme.textTheme.bodyLarge),
            ],
          ),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Resumen')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(period.name, style: theme.textTheme.titleMedium),
                StatusChip(status: declaration.status),
                Text(declaration.status.value,
                    key: const ValueKey<String>('status-value'),
                    style: theme.textTheme.labelSmall),
              ],
            ),
            const SizedBox(height: 12),
            // Validation result.
            if (validation.isValidating || (result == null && validation.errorMessage == null))
              const InlineBanner(
                  tone: BannerTone.info, message: 'Validando…')
            else if (blocking.isNotEmpty)
              InlineBanner(
                key: const ValueKey<String>('validation-errors'),
                message: 'No pasa la validación:\n• ${blocking.join('\n• ')}',
              )
            else if (validation.errorMessage != null)
              InlineBanner(message: validation.errorMessage!)
            else
              const InlineBanner(
                key: ValueKey<String>('validation-ok'),
                tone: BannerTone.info,
                message: 'Pasa todas las validaciones.',
              ),
            if (warnings.isNotEmpty) ...[
              const SizedBox(height: 8),
              InlineBanner(
                tone: BannerTone.info,
                message: 'Avisos:\n• ${warnings.join('\n• ')}',
              ),
            ],
            const SizedBox(height: 16),
            InfoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionHeader(
                      icon: Icons.person_outline, title: 'Datos'),
                  const SizedBox(height: 12),
                  row('Nombre', snapshot.fullName),
                  row('Identificación', snapshot.identification),
                  row('Institución', appointment?.workplace ?? ''),
                  row('Puesto', appointment?.position ?? ''),
                  row('Jornada', appointment?.workload ?? ''),
                  row(
                      'Vigencia',
                      '${DeclarationFormValidator.formatDate(period.startDate)} al '
                          '${DeclarationFormValidator.formatDate(period.endDate)}'),
                  row(
                      'Instituciones adicionales',
                      schedule.externalJobs
                          .map((j) => '${j.institution} (${j.workload})')
                          .join(', ')),
                  row('Observaciones', version.observations),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48)),
                    onPressed: () => context
                        .push(AppRoutes.declarationEditPath(declaration.id)),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Corregir datos'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            InfoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionHeader(
                      icon: Icons.schedule_outlined, title: 'Horario'),
                  const SizedBox(height: 12),
                  if (entries.isEmpty) const Text('Sin intervalos.'),
                  for (final e in entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                          '${e.day.title} ${e.rangeLabel} · '
                          '${TimeRules.hoursLabel(e.durationMinutes)} · '
                          '${e.institution}'),
                    ),
                  const Divider(),
                  Text(
                    'Total: ${TimeRules.hoursLabel(WeeklySchedule.totalMinutes(entries))}',
                    key: const ValueKey<String>('summary-total'),
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48)),
                    onPressed: () =>
                        context.push(LabRoutes.schedulePath(declaration.id)),
                    icon: const Icon(Icons.edit_calendar_outlined),
                    label: const Text('Corregir horario'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: declaration.status != DeclarationStatus.borrador
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton.icon(
                  key: const ValueKey<String>('validate'),
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52)),
                  onPressed: canValidate && !_validating
                      ? () => _validate(declaration)
                      : null,
                  icon: const Icon(Icons.verified_outlined),
                  label: Text(canValidate
                      ? 'Validar declaración'
                      : 'Corrija los errores para validar'),
                ),
              ),
            ),
    );
  }
}
