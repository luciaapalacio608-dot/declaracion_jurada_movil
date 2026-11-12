import 'package:declara_horario/domain/rules/schedule_rules_config.dart';
import 'package:declara_horario/domain/rules/time_rules.dart';
import 'package:declara_horario/domain/rules/workload_catalog.dart';
import 'package:declara_horario/models/institution_type.dart';

/// Fields of the general data of a declaration (R2).
enum DeclarationFormField {
  /// Full name of the declarant (from the profile, read only).
  declarantName,

  /// Identification of the declarant (from the profile, read only).
  identification,

  /// Institution of the appointment (`Appointment.workplace`).
  institution,

  /// Position (`Appointment.position`).
  position,

  /// Type of workday (`Appointment.workload`).
  workload,

  /// Start of the validity period (the period's, read only).
  startDate,

  /// End of the validity period (the period's, read only).
  endDate,
}

/// Fields of one additional institution (saved as an `ExternalJob`).
enum AdditionalInstitutionField {
  /// Name of the institution.
  name,

  /// Public, private or foundation.
  type,

  /// Position held there.
  position,

  /// Workday there.
  workload,
}

/// What the person entered for one additional institution.
class AdditionalInstitutionInput {
  const AdditionalInstitutionInput({
    this.name = '',
    this.type,
    this.position = '',
    this.workload = '',
  });

  /// Name of the institution.
  final String name;

  /// Institution type, or `null` while none is chosen.
  final InstitutionType? type;

  /// Position held there.
  final String position;

  /// Workday label of [WorkloadCatalog.externalOptions].
  final String workload;

  /// Weekly minutes of [workload], or `null` when it is not in the list.
  int? get weeklyMinutes => _externalMinutes(workload);
}

/// What the person entered in the general data form. It maps onto
/// DeclaraHorario's models when saved: `DeclarantSnapshot` (name and
/// identification), `Appointment`, `ExternalJob` and the version's
/// observations.
class DeclarationFormInput {
  const DeclarationFormInput({
    this.declarantName = '',
    this.identification = '',
    this.institution = '',
    this.position = '',
    this.workload = '',
    this.startDate,
    this.endDate,
    this.additionalInstitutions = const <AdditionalInstitutionInput>[],
    this.observations = '',
  });

  final String declarantName;
  final String identification;
  final String institution;
  final String position;

  /// Workday label of [WorkloadCatalog.options].
  final String workload;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<AdditionalInstitutionInput> additionalInstitutions;

  /// Optional free text.
  final String observations;
}

/// Problems found in a [DeclarationFormInput], one message per field.
class DeclarationFormErrors {
  const DeclarationFormErrors({
    this.fields = const <DeclarationFormField, String>{},
    this.additional = const <int, Map<AdditionalInstitutionField, String>>{},
    this.general = const <String>[],
  });

  /// Message of each general field with a problem.
  final Map<DeclarationFormField, String> fields;

  /// Messages of each additional institution with a problem, by index.
  final Map<int, Map<AdditionalInstitutionField, String>> additional;

  /// Problems that are not about one field (for example the 20-hour limit
  /// of all the other institutions together).
  final List<String> general;

  /// Whether the form is complete and consistent.
  bool get isEmpty => fields.isEmpty && additional.isEmpty && general.isEmpty;

  /// Number of problems.
  int get count =>
      fields.length +
      general.length +
      additional.values.fold<int>(0, (total, map) => total + map.length);

  /// Message of [field], or `null`.
  String? of(DeclarationFormField field) => fields[field];

  /// Message of [field] of the additional institution at [index], or `null`.
  String? ofAdditional(int index, AdditionalInstitutionField field) =>
      additional[index]?[field];

  /// Every message in form order, for the summary at the top of the form.
  List<String> get messages => <String>[
        for (final field in DeclarationFormField.values)
          ?fields[field],
        for (final index in additional.keys.toList()..sort())
          for (final field in AdditionalInstitutionField.values)
            ?additional[index]![field],
        ...general,
      ];
}

/// Required fields and consistency of the general data form (R2).
///
/// Pure Dart. Each message names the exact field, so the person knows what
/// to fix; the screen shows it under that field.
class DeclarationFormValidator {
  const DeclarationFormValidator._();

  /// Checks [input] and returns every problem found.
  static DeclarationFormErrors validate(DeclarationFormInput input) {
    final fields = <DeclarationFormField, String>{};

    void require(DeclarationFormField field, String value, String message) {
      if (value.trim().isEmpty) fields[field] = message;
    }

    require(DeclarationFormField.declarantName, input.declarantName,
        'Falta el nombre del declarante: complételo en su perfil.');
    require(DeclarationFormField.identification, input.identification,
        'Falta la identificación del declarante: complétela en su perfil.');
    require(DeclarationFormField.institution, input.institution,
        'Falta la institución del nombramiento.');
    require(DeclarationFormField.position, input.position,
        'Indique su puesto.');
    require(DeclarationFormField.workload, input.workload,
        'Seleccione el tipo de jornada.');

    final start = input.startDate;
    final end = input.endDate;
    if (start == null) {
      fields[DeclarationFormField.startDate] =
          'Falta la fecha de inicio de la vigencia.';
    }
    if (end == null) {
      fields[DeclarationFormField.endDate] =
          'Falta la fecha de fin de la vigencia.';
    }
    if (start != null && end != null && end.isBefore(start)) {
      fields[DeclarationFormField.endDate] =
          'La fecha de fin (${formatDate(end)}) es anterior a la de inicio '
          '(${formatDate(start)}).';
    }

    final additional = <int, Map<AdditionalInstitutionField, String>>{};
    for (var i = 0; i < input.additionalInstitutions.length; i++) {
      final errors = _validateAdditional(input.additionalInstitutions[i], i + 1);
      if (errors.isNotEmpty) additional[i] = errors;
    }

    // All the other institutions together: at most 20 hours a week.
    final general = <String>[];
    final externalTotal = input.additionalInstitutions
        .map((institution) => institution.weeklyMinutes ?? 0)
        .fold<int>(0, (total, minutes) => total + minutes);
    if (externalTotal > ScheduleRulesConfig.maxExternalWeeklyMinutes) {
      general.add('Las instituciones adicionales suman '
          '${TimeRules.hoursLabel(externalTotal)} por semana; el máximo es '
          '${TimeRules.hoursLabel(ScheduleRulesConfig.maxExternalWeeklyMinutes)}.');
    }

    return DeclarationFormErrors(
      fields: fields,
      additional: additional,
      general: general,
    );
  }

  /// Problems of one additional institution; [number] is 1-based, as the
  /// person sees it.
  static Map<AdditionalInstitutionField, String> _validateAdditional(
    AdditionalInstitutionInput input,
    int number,
  ) {
    final errors = <AdditionalInstitutionField, String>{};
    if (input.name.trim().isEmpty) {
      errors[AdditionalInstitutionField.name] =
          'Indique el nombre de la institución adicional $number.';
    }
    if (input.type == null) {
      errors[AdditionalInstitutionField.type] =
          'Seleccione si la institución adicional $number es pública, '
          'privada o fundación.';
    }
    if (input.position.trim().isEmpty) {
      errors[AdditionalInstitutionField.position] =
          'Indique su puesto en la institución adicional $number.';
    }
    if (input.workload.trim().isEmpty) {
      errors[AdditionalInstitutionField.workload] =
          'Seleccione la jornada en la institución adicional $number.';
    } else if (input.weeklyMinutes == null) {
      // firestore.rules only accepts these workdays at another institution.
      errors[AdditionalInstitutionField.workload] =
          'La jornada en la institución adicional $number debe ser una de la '
          'lista (máximo ${WorkloadCatalog.externalOptions.last.label}).';
    }
    return errors;
  }

  /// 2026-08-03 -> "03/08/2026".
  static String formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}

int? _externalMinutes(String label) {
  for (final option in WorkloadCatalog.externalOptions) {
    if (option.label == label.trim()) return option.weeklyMinutes;
  }
  return null;
}
