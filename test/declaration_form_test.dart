import 'package:declara_horario/models/institution_type.dart';
import 'package:declaracion_jurada_movil/logic/declaration_form.dart';
import 'package:flutter_test/flutter_test.dart';

// Fictitious data only.
DeclarationFormInput _complete({
  String position = 'Docente',
  String workload = '1/4 TC',
  DateTime? start,
  DateTime? end,
  List<AdditionalInstitutionInput> additional =
      const <AdditionalInstitutionInput>[],
}) =>
    DeclarationFormInput(
      declarantName: 'Ana Prueba Ficticia',
      identification: '100000002',
      institution: 'UCR · Sede del Sur (ficticia)',
      position: position,
      workload: workload,
      startDate: start ?? DateTime(2026, 8, 3),
      endDate: end ?? DateTime(2026, 12, 12),
      additionalInstitutions: additional,
    );

void main() {
  group('DeclarationFormValidator (R2)', () {
    test('a complete form has no errors', () {
      expect(DeclarationFormValidator.validate(_complete()).isEmpty, isTrue);
    });

    test('missing required fields are reported one by one', () {
      final errors = DeclarationFormValidator.validate(
        const DeclarationFormInput(),
      );
      expect(errors.of(DeclarationFormField.declarantName), isNotNull);
      expect(errors.of(DeclarationFormField.identification), isNotNull);
      expect(errors.of(DeclarationFormField.institution), isNotNull);
      expect(errors.of(DeclarationFormField.position), isNotNull);
      expect(errors.of(DeclarationFormField.workload), isNotNull);
      expect(errors.of(DeclarationFormField.startDate), isNotNull);
      expect(errors.of(DeclarationFormField.endDate), isNotNull);
      expect(errors.count, 7);
    });

    test('blank text counts as missing', () {
      final errors =
          DeclarationFormValidator.validate(_complete(position: '   '));
      expect(errors.of(DeclarationFormField.position), 'Indique su puesto.');
    });

    test('end date before start date is an error', () {
      final errors = DeclarationFormValidator.validate(_complete(
        start: DateTime(2026, 12, 12),
        end: DateTime(2026, 8, 3),
      ));
      expect(errors.of(DeclarationFormField.endDate),
          contains('03/08/2026'));
    });

    test('additional institution needs every field', () {
      final errors = DeclarationFormValidator.validate(_complete(
        additional: const [AdditionalInstitutionInput()],
      ));
      expect(errors.ofAdditional(0, AdditionalInstitutionField.name),
          isNotNull);
      expect(errors.ofAdditional(0, AdditionalInstitutionField.type),
          isNotNull);
      expect(errors.ofAdditional(0, AdditionalInstitutionField.position),
          isNotNull);
      expect(errors.ofAdditional(0, AdditionalInstitutionField.workload),
          isNotNull);
    });

    test('weekly minutes follow the workday (as firestore.rules requires)',
        () {
      expect(
          const AdditionalInstitutionInput(workload: '1/8 TC').weeklyMinutes,
          300);
      expect(
          const AdditionalInstitutionInput(workload: '1/2 TC').weeklyMinutes,
          1200);
      expect(const AdditionalInstitutionInput(workload: 'TC').weeklyMinutes,
          isNull);
    });

    test('additional institutions together cannot exceed 20 h', () {
      const job = AdditionalInstitutionInput(
        name: 'Colegio Ficticio',
        type: InstitutionType.private,
        position: 'Profesor',
        workload: '1/2 TC',
      );
      expect(
          DeclarationFormValidator.validate(_complete(additional: [job]))
              .isEmpty,
          isTrue);
      final errors =
          DeclarationFormValidator.validate(_complete(additional: [job, job]));
      expect(errors.general, hasLength(1));
      expect(errors.messages.last, contains('máximo'));
    });
  });
}
