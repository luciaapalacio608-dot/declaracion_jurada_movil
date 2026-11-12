import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/declaracion.dart';

class BorradorRepository {
  static const _clave = 'declaraciones';

  Future<List<Declaracion>> obtenerTodas() async {
    final prefs = await SharedPreferences.getInstance();
    final lista = prefs.getStringList(_clave) ?? [];
    return lista
        .map((s) => Declaracion.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
  }

  Future<void> guardar(Declaracion d) async {
    final todas = await obtenerTodas();
    final idx = todas.indexWhere((x) => x.id == d.id);
    if (idx >= 0) {
      todas[idx] = d;
    } else {
      todas.add(d);
    }
    await _escribir(todas);
  }

  Future<void> eliminar(String id) async {
    final todas = await obtenerTodas();
    todas.removeWhere((x) => x.id == id);
    await _escribir(todas);
  }

  Future<void> _escribir(List<Declaracion> todas) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        _clave, todas.map((d) => jsonEncode(d.toJson())).toList());
  }
}