class IntervaloHorario {
  final String dia;
  final int inicio; // minutos desde medianoche
  final int fin; // minutos desde medianoche
  final String institucion;

  const IntervaloHorario({
    required this.dia,
    required this.inicio,
    required this.fin,
    required this.institucion,
  });

  int get duracionMinutos => fin > inicio ? fin - inicio : 0;

  Map<String, dynamic> toJson() => {
        'dia': dia,
        'inicio': inicio,
        'fin': fin,
        'institucion': institucion,
      };

  factory IntervaloHorario.fromJson(Map<String, dynamic> j) => IntervaloHorario(
        dia: j['dia'],
        inicio: j['inicio'],
        fin: j['fin'],
        institucion: j['institucion'],
      );
}

String formatoHora(int minutos) {
  final h = minutos ~/ 60;
  final m = minutos % 60;
  final sufijo = h >= 12 ? 'p. m.' : 'a. m.';
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$h12:${m.toString().padLeft(2, '0')} $sufijo';
}

String formatoDuracion(int minutos) => '${minutos ~/ 60} h ${minutos % 60} min';