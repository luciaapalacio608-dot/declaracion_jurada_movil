import '../models/intervalo_horario.dart';

class ValidadorHorarios {
  static const dias = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
  ];

  static String _rango(IntervaloHorario i) =>
      '${formatoHora(i.inicio)} a ${formatoHora(i.fin)}';

  /// Lista de problemas concretos. Lista vacía = horario válido.
  static List<String> validar(List<IntervaloHorario> intervalos) {
    final errores = <String>[];

    for (final i in intervalos) {
      if (i.fin <= i.inicio) {
        errores.add(
            '${i.dia}: la hora de fin (${formatoHora(i.fin)}) debe ser posterior a la de inicio (${formatoHora(i.inicio)}).');
      }
    }

    for (var a = 0; a < intervalos.length; a++) {
      for (var b = a + 1; b < intervalos.length; b++) {
        final x = intervalos[a];
        final y = intervalos[b];
        if (x.dia != y.dia) continue;
        if (x.fin <= x.inicio || y.fin <= y.inicio) continue;
        if (x.inicio < y.fin && y.inicio < x.fin) {
          errores.add(
              '${x.dia}: el horario de ${_rango(x)} (${x.institucion}) se traslapa con ${_rango(y)} (${y.institucion}). Corrija o elimine uno de los dos.');
        }
      }
    }
    return errores;
  }

  /// Posiciones de los intervalos con problemas (para marcarlos en rojo).
  static Set<int> indicesEnConflicto(List<IntervaloHorario> intervalos) {
    final r = <int>{};
    for (var a = 0; a < intervalos.length; a++) {
      final x = intervalos[a];
      if (x.fin <= x.inicio) r.add(a);
      for (var b = a + 1; b < intervalos.length; b++) {
        final y = intervalos[b];
        if (x.dia != y.dia) continue;
        if (x.fin <= x.inicio || y.fin <= y.inicio) continue;
        if (x.inicio < y.fin && y.inicio < x.fin) {
          r.add(a);
          r.add(b);
        }
      }
    }
    return r;
  }
}