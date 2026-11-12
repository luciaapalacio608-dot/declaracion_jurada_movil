import 'package:declara_horario/domain/rules/appointment_defaults.dart';
import 'package:declara_horario/domain/rules/course_rules.dart';
import 'package:declara_horario/domain/rules/workload_catalog.dart';
import 'package:declara_horario/features/auth/state/auth_state.dart';
import 'package:declara_horario/features/declarations/state/declaration_state.dart';
import 'package:declara_horario/features/declarations/state/schedule_state.dart';
import 'package:declara_horario/features/declarations/widgets/position_field.dart';
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

/// R2: general data of a declaration — declarant, institution and position,
/// workday, validity, additional institutions and observations.
///
/// Reads and saves through DeclaraHorario's [DeclarationState] and
/// [ScheduleState] (same repositories, rules and audit events as the full
/// system). Name, identification, institution and validity are shown but
/// not typed: DeclaraHorario takes them from the profile and the period, and
/// firestore.rules requires the period's dates.
class FormularioScreen extends StatefulWidget {
  const FormularioScreen({super.key, required this.declarationId});

  final String declarationId;

  @override
  State<FormularioScreen> createState() => _FormularioScreenState();
}

/// Editable copy of one additional institution.
class _AdditionalDraft {
  /// A new institution, not saved yet.
  _AdditionalDraft.empty()
      : id = '',
        name = TextEditingController(),
        position = TextEditingController(),
        blocks = const <TimeBlock>[];

  /// An institution already saved in Firestore.
  _AdditionalDraft.of(ExternalJob job)
      : id = job.id,
        name = TextEditingController(text: job.institution),
        position = TextEditingController(text: job.position),
        type = job.institutionType,
        workload = job.workload,
        blocks = job.blocks;

  /// Firestore id, or `''` while it has never been saved.
  final String id;
  final TextEditingController name;
  final TextEditingController position;
  InstitutionType? type;
  String? workload;

  /// Its schedule, kept as it is: it is edited in the schedule screen.
  final List<TimeBlock> blocks;

  AdditionalInstitutionInput get input => AdditionalInstitutionInput(
        name: name.text,
        type: type,
        position: position.text,
        workload: workload ?? '',
      );

  void dispose() {
    name.dispose();
    position.dispose();
  }
}

class _FormularioScreenState extends State<FormularioScreen> {
  final _position = TextEditingController();
  final _observations = TextEditingController();
  String? _workload;
  List<_AdditionalDraft> _additional = <_AdditionalDraft>[];
  final Set<String> _removedJobIds = <String>{};

  /// Version whose content is being listened to.
  String? _watchingVersion;

  /// Data last copied into the form; new data from Firestore refills the
  /// form while the person has not changed anything.
  Object? _loadedAppointments;
  Object? _loadedJobs;
  Object? _loadedVersion;
  Object? _loadedAssignment;

  /// Whether the controllers are being filled from Firestore (not typed).
  bool _filling = false;
  bool _dirty = false;
  bool _saving = false;

  /// Shown after the first attempt to save, then kept up to date.
  DeclarationFormErrors? _errors;

  @override
  void initState() {
    super.initState();
    _position.addListener(_onChanged);
    _observations.addListener(_onChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<DeclarationState>().watchDeclaration(widget.declarationId);
    });
  }

  @override
  void dispose() {
    _position.dispose();
    _observations.dispose();
    for (final draft in _additional) {
      draft.dispose();
    }
    super.dispose();
  }

  void _onChanged() {
    if (_filling || !mounted) return;
    setState(() {
      _dirty = true;
      if (_errors != null) _errors = _validate();
    });
  }

  /// Starts listening to the version and the period once the declaration
  /// has arrived.
  void _watchContent(Declaration declaration) {
    if (_watchingVersion == declaration.currentVersionId) return;
    _watchingVersion = declaration.currentVersionId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ScheduleState>().watchVersion(VersionRef(
            declarationId: declaration.id,
            versionId: declaration.currentVersionId,
          ));
      context.read<DeclarationState>().watchContextOf(declaration);
    });
  }

  /// Copies what is saved into the form, unless the person is editing.
  void _fill(ScheduleState schedule, DeclarationState declarations) {
    if (_dirty) return;
    final version = schedule.version;
    if (version == null) return;
    if (identical(_loadedAppointments, schedule.appointments) &&
        identical(_loadedJobs, schedule.externalJobs) &&
        identical(_loadedVersion, version) &&
        identical(_loadedAssignment, declarations.currentAssignment)) {
      return;
    }
    _loadedAppointments = schedule.appointments;
    _loadedJobs = schedule.externalJobs;
    _loadedVersion = version;
    _loadedAssignment = declarations.currentAssignment;

    _filling = true;
    final appointment =
        schedule.appointments.isEmpty ? null : schedule.appointments.first;
    _position.text = appointment?.position ?? '';
    _workload = _knownWorkload(appointment?.workload) ??
        _assignedWorkload(declarations.currentAssignment);
    _observations.text = version.observations;
    for (final draft in _additional) {
      draft.dispose();
    }
    _additional = schedule.externalJobs.map(_AdditionalDraft.of).toList();
    _removedJobIds.clear();
    _filling = false;
  }

  static String? _knownWorkload(String? label) =>
      WorkloadCatalog.options.any((option) => option.label == label)
          ? label
          : null;

  /// The workday of the coordinator's assignment ("1/4 TC"), as
  /// DeclaraHorario's editor proposes it.
  static String? _assignedWorkload(WorkloadAssignment? assignment) {
    if (assignment == null) return null;
    final minutes = CourseRules.authorizedOf(assignment)?.workdayMinutes;
    return minutes == null ? null : WorkloadCatalog.labelFor(minutes);
  }

  DeclarationFormInput _input() {
    final schedule = context.read<ScheduleState>();
    final period = context.read<DeclarationState>().currentPeriod;
    final snapshot = schedule.version?.declarantSnapshot;
    return DeclarationFormInput(
      declarantName: snapshot?.fullName ?? '',
      identification: snapshot?.identification ?? '',
      institution:
          snapshot == null ? '' : AppointmentDefaults.workplaceOf(snapshot),
      position: _position.text,
      workload: _workload ?? '',
      startDate: period?.startDate,
      endDate: period?.endDate,
      additionalInstitutions: [for (final d in _additional) d.input],
      observations: _observations.text,
    );
  }

  DeclarationFormErrors _validate() =>
      DeclarationFormValidator.validate(_input());

  Future<void> _save(Declaration declaration) async {
    final errors = _validate();
    setState(() => _errors = errors);
    final messenger = ScaffoldMessenger.of(context);
    if (!errors.isEmpty) {
      messenger.showSnackBar(SnackBar(
        content: Text(errors.count == 1
            ? 'Hay 1 dato por corregir.'
            : 'Hay ${errors.count} datos por corregir.'),
      ));
      return;
    }

    final user = context.read<AuthState>().currentUser;
    final schedule = context.read<ScheduleState>();
    final period = context.read<DeclarationState>().currentPeriod;
    final snapshot = schedule.version?.declarantSnapshot;
    if (user == null || period == null || snapshot == null) return;

    setState(() => _saving = true);
    final ref = VersionRef(
      declarationId: declaration.id,
      versionId: declaration.currentVersionId,
    );
    final status = declaration.status;
    final existing =
        schedule.appointments.isEmpty ? null : schedule.appointments.first;

    // The appointment keeps its schedule (edited in the schedule screen);
    // workplace and dates always come from the profile and the period.
    var ok = await schedule.saveAppointment(
      ref: ref,
      actor: user,
      declarationStatus: status,
      appointment: AppointmentDefaults.apply(
        Appointment(
          id: existing?.id ?? '',
          workplace: '',
          position: _position.text.trim(),
          workload: _workload!,
          startDate: period.startDate,
          endDate: period.endDate,
          blocks: existing?.blocks ?? const <TimeBlock>[],
          projects: existing?.projects ?? const <ProjectHours>[],
        ),
        snapshot: snapshot,
        period: period,
      ),
    );
    for (final id in _removedJobIds) {
      if (!ok) break;
      ok = await schedule.removeExternalJob(
        ref: ref,
        externalJobId: id,
        actor: user,
        declarationStatus: status,
      );
    }
    for (final draft in _additional) {
      if (!ok) break;
      ok = await schedule.saveExternalJob(
        ref: ref,
        actor: user,
        declarationStatus: status,
        externalJob: ExternalJob(
          id: draft.id,
          institution: draft.name.text.trim(),
          institutionType: draft.type!,
          position: draft.position.text.trim(),
          workload: draft.workload!,
          weeklyMinutes: draft.input.weeklyMinutes,
          startDate: period.startDate,
          endDate: period.endDate,
          blocks: draft.blocks,
        ),
      );
    }
    final observations = _observations.text.trim();
    if (ok && observations != (schedule.version?.observations ?? '')) {
      ok = await schedule.updateObservations(
        ref: ref,
        observations: observations,
        actor: user,
        declarationStatus: status,
      );
    }

    if (!mounted) return;
    setState(() {
      _saving = false;
      // Saved: the next data from Firestore (with the new ids) refills
      // the form.
      if (ok) {
        _dirty = false;
        _loadedAppointments = null;
      }
    });
    messenger.showSnackBar(SnackBar(
      content: Text(ok
          ? 'Borrador guardado.'
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
    final declaration = declarations.current;

    if (declaration == null || declaration.id != widget.declarationId) {
      return Scaffold(
        appBar: AppBar(title: const Text('Datos de la declaración')),
        body: declarations.errorMessage != null && !declarations.isLoading
            ? ErrorView(message: declarations.errorMessage!)
            : const LoadingView(),
      );
    }
    _watchContent(declaration);
    _fill(schedule, declarations);

    final snapshot = schedule.version?.declarantSnapshot;
    final period = declarations.currentPeriod;
    final editable = declaration.status == DeclarationStatus.borrador ||
        declaration.status == DeclarationStatus.validada;

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
        appBar: AppBar(title: const Text('Datos de la declaración')),
        body: snapshot == null || period == null
            ? const LoadingView()
            : SafeArea(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    _statusRow(declaration, period),
                    if (!editable) ...[
                      const SizedBox(height: 12),
                      const InlineBanner(
                        tone: BannerTone.info,
                        message: 'Esta declaración ya no está en borrador: '
                            'en el laboratorio solo se puede consultar.',
                      ),
                    ],
                    if (declaration.status == DeclarationStatus.validada) ...[
                      const SizedBox(height: 12),
                      const InlineBanner(
                        tone: BannerTone.info,
                        message: 'Está VALIDADA. Si guarda cambios, vuelve a '
                            'BORRADOR y deberá validarla otra vez.',
                      ),
                    ],
                    if (_errors != null && !_errors!.isEmpty) ...[
                      const SizedBox(height: 12),
                      InlineBanner(
                        message: 'Corrija estos datos:\n• '
                            '${_errors!.messages.join('\n• ')}',
                      ),
                    ],
                    const SizedBox(height: 16),
                    _declarantSection(snapshot),
                    const SizedBox(height: 16),
                    _appointmentSection(snapshot, period, editable),
                    const SizedBox(height: 16),
                    _additionalSection(editable),
                    const SizedBox(height: 16),
                    _observationsSection(editable),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      key: const ValueKey<String>('go-schedule'),
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48)),
                      onPressed: () => context
                          .push(LabRoutes.schedulePath(declaration.id)),
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: const Text('Horario semanal'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48)),
                      onPressed: () => context
                          .push(LabRoutes.summaryPath(declaration.id)),
                      icon: const Icon(Icons.fact_check_outlined),
                      label: const Text('Ver resumen'),
                    ),
                  ],
                ),
              ),
        bottomNavigationBar: snapshot == null || period == null || !editable
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: FilledButton.icon(
                    key: const ValueKey<String>('save-draft'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    onPressed: _saving ? null : () => _save(declaration),
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: const Text('Guardar borrador'),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _statusRow(Declaration declaration, Period period) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(period.name, style: theme.textTheme.titleMedium),
        StatusChip(status: declaration.status),
        Text(declaration.status.value,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }

  Widget _section({
    required IconData icon,
    required String title,
    String? subtitle,
    required List<Widget> children,
  }) {
    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(icon: icon, title: title, subtitle: subtitle),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  /// A value the system already knows, shown but not editable.
  Widget _readOnly(String label, String value,
      {String? helper, String? error}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          helperText: error == null ? helper : null,
          helperMaxLines: 3,
          errorText: error,
          errorMaxLines: 3,
          suffixIcon: const Icon(Icons.lock_outline, size: 18),
        ),
        child: Text(value.isEmpty ? '—' : value),
      ),
    );
  }

  Widget _declarantSection(DeclarantSnapshot snapshot) {
    final errors = _errors;
    return _section(
      icon: Icons.person_outline,
      title: 'Declarante',
      subtitle: 'Datos de su perfil',
      children: [
        _readOnly('Nombre completo', snapshot.fullName,
            error: errors?.of(DeclarationFormField.declarantName)),
        _readOnly('Identificación', snapshot.identification,
            helper: 'Se cambian en su perfil de DeclaraHorario.',
            error: errors?.of(DeclarationFormField.identification)),
      ],
    );
  }

  Widget _appointmentSection(
      DeclarantSnapshot snapshot, Period period, bool editable) {
    final errors = _errors;
    final theme = Theme.of(context);
    return _section(
      icon: Icons.work_outline,
      title: 'Nombramiento',
      subtitle: 'Institución, puesto, jornada y vigencia',
      children: [
        _readOnly('Institución', AppointmentDefaults.workplaceOf(snapshot),
            helper: 'Sale de su sede y carrera.',
            error: errors?.of(DeclarationFormField.institution)),
        IgnorePointer(
          ignoring: !editable,
          child: PositionField(
            controller: _position,
            suggestions: PositionField.university,
            label: 'Puesto',
          ),
        ),
        if (errors?.of(DeclarationFormField.position) case final message?)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 12),
            child: Text(message,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.error)),
          ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          // Keyed by value: rebuilt when Firestore refills the form.
          key: ValueKey<String>('workload-$_workload'),
          initialValue: _workload,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Tipo de jornada',
            helperText: 'TC = tiempo completo (40 h por semana).',
            errorText: errors?.of(DeclarationFormField.workload),
          ),
          items: [
            for (final option in WorkloadCatalog.options)
              DropdownMenuItem<String>(
                value: option.label,
                child: Text('${option.label} · '
                    '${option.weeklyMinutes ~/ 60} h por semana'),
              ),
          ],
          onChanged: editable
              ? (value) {
                  _workload = value;
                  _onChanged();
                }
              : null,
        ),
        const SizedBox(height: 16),
        _readOnly(
          'Vigencia',
          '${DeclarationFormValidator.formatDate(period.startDate)} al '
              '${DeclarationFormValidator.formatDate(period.endDate)}',
          helper: 'Es la del período ${period.name}.',
          error: errors?.of(DeclarationFormField.endDate) ??
              errors?.of(DeclarationFormField.startDate),
        ),
      ],
    );
  }

  Widget _additionalSection(bool editable) {
    return _section(
      icon: Icons.apartment_outlined,
      title: 'Instituciones adicionales',
      subtitle: 'Otros trabajos, si los tiene (máximo 20 h en total)',
      children: [
        if (_additional.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text('No ha agregado otras instituciones.',
                style: Theme.of(context).textTheme.bodyMedium),
          ),
        for (var i = 0; i < _additional.length; i++)
          _additionalCard(i, editable),
        if (editable)
          OutlinedButton.icon(
            key: const ValueKey<String>('add-institution'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: () {
              _additional.add(_AdditionalDraft.empty());
              _onChanged();
            },
            icon: const Icon(Icons.add),
            label: const Text('Agregar institución'),
          ),
      ],
    );
  }

  static const Map<InstitutionType, String> _typeLabels = {
    InstitutionType.public: 'Pública',
    InstitutionType.private: 'Privada',
    InstitutionType.foundation: 'Fundación',
  };

  Widget _additionalCard(int index, bool editable) {
    final draft = _additional[index];
    final errors = _errors;
    final theme = Theme.of(context);
    String? error(AdditionalInstitutionField field) =>
        errors?.ofAdditional(index, field);

    return Container(
      key: ObjectKey(draft),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Institución ${index + 1}',
                    style: theme.textTheme.titleSmall),
              ),
              if (editable)
                IconButton(
                  tooltip: 'Quitar institución ${index + 1}',
                  onPressed: () {
                    final removed = _additional.removeAt(index);
                    if (removed.id.isNotEmpty) _removedJobIds.add(removed.id);
                    _onChanged();
                    removed.dispose();
                  },
                  icon: const Icon(Icons.delete_outline),
                ),
            ],
          ),
          TextField(
            controller: draft.name,
            enabled: editable,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => _onChanged(),
            decoration: InputDecoration(
              labelText: 'Nombre de la institución',
              errorText: error(AdditionalInstitutionField.name),
              errorMaxLines: 3,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<InstitutionType>(
            key: ValueKey<Object?>(draft.type),
            initialValue: draft.type,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Tipo de institución',
              errorText: error(AdditionalInstitutionField.type),
              errorMaxLines: 3,
            ),
            items: [
              for (final entry in _typeLabels.entries)
                DropdownMenuItem(value: entry.key, child: Text(entry.value)),
            ],
            onChanged: editable
                ? (value) {
                    draft.type = value;
                    _onChanged();
                  }
                : null,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: draft.position,
            enabled: editable,
            onChanged: (_) => _onChanged(),
            decoration: InputDecoration(
              labelText: 'Puesto',
              hintText: 'Por ejemplo: Profesor',
              errorText: error(AdditionalInstitutionField.position),
              errorMaxLines: 3,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey<String?>(draft.workload),
            initialValue: WorkloadCatalog.externalOptions
                    .any((o) => o.label == draft.workload)
                ? draft.workload
                : null,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Jornada',
              errorText: error(AdditionalInstitutionField.workload),
              errorMaxLines: 3,
            ),
            items: [
              for (final option in WorkloadCatalog.externalOptions)
                DropdownMenuItem<String>(
                  value: option.label,
                  child: Text('${option.label} · '
                      '${option.weeklyMinutes ~/ 60} h por semana'),
                ),
            ],
            onChanged: editable
                ? (value) {
                    draft.workload = value;
                    _onChanged();
                  }
                : null,
          ),
        ],
      ),
    );
  }

  Widget _observationsSection(bool editable) {
    return _section(
      icon: Icons.notes_outlined,
      title: 'Observaciones',
      subtitle: 'Opcional',
      children: [
        TextField(
          controller: _observations,
          enabled: editable,
          minLines: 3,
          maxLines: 6,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Algo que su revisor deba saber.',
          ),
        ),
      ],
    );
  }
}
