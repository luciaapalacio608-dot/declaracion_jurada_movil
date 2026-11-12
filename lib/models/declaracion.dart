import 'intervalo_horario.dart';

class Declaracion {
  static const tiposJornada = [
    'Tiempo completo',
    'Medio tiempo',
    'Cuarto de tiempo',
    'Interino',
    'Propiedad',
  ];

  String id;
  String nombre;
  String identificacion;
  String institucion;
  String puesto;
  String tipoJornada;
  String vigenciaInicio;
  String vigenciaFin;
  String institucionesAdicionales;
  String observaciones;
  String estado; // BORRADOR o VALIDADA
  List<IntervaloHorario> intervalos;

  Declaracion({
    String? id,
    this.nombre = '',
    this.identificacion = '',
    this.institucion = '',
    this.puesto = '',
    this.tipoJornada = 'Tiempo completo',
    this.vigenciaInicio = '',
    this.vigenciaFin = '',
    this.institucionesAdicionales = '',
    this.observaciones = '',
    this.estado = 'BORRADOR',
    List<IntervaloHorario>? intervalos,
  })  : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        intervalos = intervalos ?? [];

  int get totalMinutos =>
      intervalos.fold(0, (suma, i) => suma + i.duracionMinutos);

  List<String> camposFaltantes() {
    final campos = <String, String>{
      'Nombre': nombre,
      'Identificación': identificacion,
      'Institución': institucion,
      'Puesto': puesto,
      'Inicio de vigencia': vigenciaInicio,
      'Fin de vigencia': vigenciaFin,
    };
    final faltan = campos.entries
        .where((e) => e.value.trim().isEmpty)
        .map((e) => e.key)
        .toList();
    if (intervalos.isEmpty) faltan.add('Al menos un intervalo de horario');
    return faltan;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'identificacion': identificacion,
        'institucion': institucion,
        'puesto': puesto,
        'tipoJornada': tipoJornada,
        'vigenciaInicio': vigenciaInicio,
        'vigenciaFin': vigenciaFin,
        'institucionesAdicionales': institucionesAdicionales,
        'observaciones': observaciones,
        'estado': estado,
        'intervalos': intervalos.map((i) => i.toJson()).toList(),
      };

  factory Declaracion.fromJson(Map<String, dynamic> j) => Declaracion(
        id: j['id'],
        nombre: j['nombre'] ?? '',
        identificacion: j['identificacion'] ?? '',
        institucion: j['institucion'] ?? '',
        puesto: j['puesto'] ?? '',
        tipoJornada: j['tipoJornada'] ?? 'Tiempo completo',
        vigenciaInicio: j['vigenciaInicio'] ?? '',
        vigenciaFin: j['vigenciaFin'] ?? '',
        institucionesAdicionales: j['institucionesAdicionales'] ?? '',
        observaciones: j['observaciones'] ?? '',
        estado: j['estado'] ?? 'BORRADOR',
        intervalos: (j['intervalos'] as List? ?? [])
            .map((i) => IntervaloHorario.fromJson(Map<String, dynamic>.from(i)))
            .toList(),
      );
}