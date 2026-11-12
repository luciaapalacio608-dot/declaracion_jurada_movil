import 'package:flutter/material.dart';

class AppTheme {
  static const Color celeste = Color(0xFF00C0F3);
  static const Color azul = Color(0xFF005DA4);
  static const Color blanco = Color(0xFFFFFFFF);
  static const Color amarillo = Color(0xFFFFE06A);
  static const Color verde = Color(0xFF6DC067);

  static const Color fondo = Color(0xFFF2F7FB);
  static const Color texto = Color(0xFF1B2A38);
  static const Color borde = Color(0xFFB8CFE0);
  static const Color error = Color(0xFFB3261E);
  static const Color errorFondo = Color(0xFFFDECEA);
  static const Color azulClaro = Color(0xFFD6ECFA);

  static OutlineInputBorder _borde(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c, width: w),
      );

  static ThemeData get tema {
    final esquema = ColorScheme.fromSeed(seedColor: azul).copyWith(
      primary: azul,
      onPrimary: blanco,
      secondary: celeste,
      error: error,
    );
    final formaBoton = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Arial',
      colorScheme: esquema,
      scaffoldBackgroundColor: fondo,
      appBarTheme: const AppBarTheme(
        backgroundColor: azul,
        foregroundColor: blanco,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
            fontSize: 20, fontWeight: FontWeight.w700, color: blanco, fontFamily: 'Arial'),
      ),
      cardTheme: CardThemeData(
        color: blanco,
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFDCE6EE)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: azul,
          foregroundColor: blanco,
          disabledBackgroundColor: const Color(0xFFD5E0E9),
          disabledForegroundColor: const Color(0xFF5B6B7A),
          minimumSize: const Size.fromHeight(52),
          shape: formaBoton,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: azul,
          side: const BorderSide(color: azul),
          minimumSize: const Size.fromHeight(48),
          shape: formaBoton,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: azul,
        foregroundColor: blanco,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: blanco,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: _borde(borde),
        enabledBorder: _borde(borde),
        focusedBorder: _borde(azul, 2),
        errorBorder: _borde(error),
        focusedErrorBorder: _borde(error, 2),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: blanco,
        selectedColor: azulClaro,
        checkmarkColor: azul,
        labelStyle: const TextStyle(color: texto, fontSize: 14),
        side: const BorderSide(color: borde),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    );
  }
}

/// Etiqueta de estado (BORRADOR / VALIDADA)
class EtiquetaEstado extends StatelessWidget {
  final String estado;
  const EtiquetaEstado(this.estado, {super.key});

  @override
  Widget build(BuildContext context) {
    final validada = estado == 'VALIDADA';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: validada ? AppTheme.verde : AppTheme.amarillo,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(validada ? Icons.check_circle : Icons.edit_note,
              size: 14, color: Colors.black87),
          const SizedBox(width: 4),
          Text(estado,
              style: const TextStyle(
                  color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }
}

/// Indicador de pasos para el AppBar (paso 1, 2 o 3)
class PasosHeader extends StatelessWidget {
  final int paso;
  const PasosHeader({super.key, required this.paso});

  static const _nombres = ['Datos', 'Horarios', 'Resumen'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          for (var i = 1; i <= 3; i++) ...[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 5,
                    decoration: BoxDecoration(
                      color: i <= paso ? AppTheme.celeste : const Color(0x55FFFFFF),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('$i. ${_nombres[i - 1]}',
                      style: TextStyle(
                        color: AppTheme.blanco,
                        fontSize: 12,
                        fontWeight: i == paso ? FontWeight.bold : FontWeight.normal,
                      )),
                ],
              ),
            ),
            if (i < 3) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

/// Tarjeta con título e ícono para agrupar campos
class TarjetaSeccion extends StatelessWidget {
  final String titulo;
  final IconData icono;
  final List<Widget> hijos;
  const TarjetaSeccion({
    super.key,
    required this.titulo,
    required this.icono,
    required this.hijos,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icono, color: AppTheme.azul),
              const SizedBox(width: 8),
              Expanded(
                child: Text(titulo,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.azul)),
              ),
            ]),
            const SizedBox(height: 14),
            ...hijos,
          ],
        ),
      ),
    );
  }
}