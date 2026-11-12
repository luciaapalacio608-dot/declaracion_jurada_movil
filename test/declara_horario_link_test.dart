import 'package:declara_horario/domain/rules/time_rules.dart';
import 'package:declara_horario/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Confirms the lab reaches DeclaraHorario as a package: the statuses and
/// rules used later come from there, not from copies in this project.
void main() {
  test('declaration statuses keep the original system names', () {
    expect(
      DeclarationStatus.values.map((status) => status.value),
      containsAll(<String>[
        'BORRADOR',
        'VALIDADA',
        'PENDIENTE_FIRMA_DECLARANTE',
        'FIRMADA_POR_DECLARANTE',
        'PENDIENTE_FIRMA_SUPERIOR',
        'DEVUELTA',
        'ANULADA',
      ]),
    );
  });

  test('time rules come from DeclaraHorario', () {
    expect(TimeRules.format(8 * 60), '08:00');
    expect(TimeRules.isValidRange(8 * 60, 12 * 60), isTrue);
  });
}
