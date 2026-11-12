import 'package:declara_horario/shared/widgets/app_components.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/lab_routes.dart';

/// Shown for a path the lab does not have (for example a link of the full
/// DeclaraHorario system that is out of the lab's scope).
class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pantalla no disponible')),
      body: EmptyState(
        icon: Icons.explore_off_outlined,
        title: 'Esta pantalla no es parte del laboratorio',
        message: 'El laboratorio solo incluye la declaración, su horario, '
            'la validación y el resumen.',
        action: FilledButton(
          onPressed: () => context.go(LabRoutes.home),
          child: const Text('Ir a mis declaraciones'),
        ),
      ),
    );
  }
}
