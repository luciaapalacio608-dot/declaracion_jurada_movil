import 'package:declara_horario/features/declarations/state/declaration_state.dart';
import 'package:declara_horario/features/declarations/state/schedule_state.dart';
import 'package:declara_horario/models/models.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

/// Listens to one declaration, its current version and its period through
/// DeclaraHorario's [DeclarationState] and [ScheduleState].
mixin DeclarationWatch<T extends StatefulWidget> on State<T> {
  /// Id of the declaration to listen to.
  String get watchedDeclarationId;

  String? _watchingVersion;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<DeclarationState>().watchDeclaration(watchedDeclarationId);
    });
  }

  /// The declaration once loaded; also starts listening to its content.
  Declaration? watchedDeclaration(DeclarationState state) {
    final declaration = state.current;
    if (declaration == null || declaration.id != watchedDeclarationId) {
      return null;
    }
    if (_watchingVersion != declaration.currentVersionId) {
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
    return declaration;
  }
}
