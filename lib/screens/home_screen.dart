import 'package:declara_horario/core/routing/app_routes.dart';
import 'package:declara_horario/domain/rules/one_per_period.dart';
import 'package:declara_horario/features/auth/state/auth_state.dart';
import 'package:declara_horario/features/declarations/state/declaration_state.dart';
import 'package:declara_horario/models/models.dart';
import 'package:declara_horario/shared/widgets/app_components.dart';
import 'package:declara_horario/shared/widgets/error_view.dart';
import 'package:declara_horario/shared/widgets/loading_view.dart';
import 'package:declara_horario/shared/widgets/status_chip.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

/// R1: main screen of the Sistema de Declaraciones Juradas. Lists the
/// declarant's declarations with their status and creates new ones.
///
/// Data, creation rules (open period, one per period, coordinator
/// assignment) and statuses all come from DeclaraHorario's
/// [DeclarationState]; this screen is only the mobile presentation.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    // Subscribing notifies listeners, which is not allowed while building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final user = context.read<AuthState>().currentUser;
      final state = context.read<DeclarationState>();
      if (user != null) state.watchMyDeclarations(user.uid);
      state.watchEnabledPeriods();
    });
  }

  Future<void> _create() async {
    final user = context.read<AuthState>().currentUser;
    final state = context.read<DeclarationState>();
    final messenger = ScaffoldMessenger.of(context);
    if (user == null) return;

    final superiorUid = user.superiorUid;
    if (superiorUid == null || superiorUid.isEmpty) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Un administrador debe asignarle un revisor antes de '
            'crear una declaración.'),
      ));
      return;
    }
    final period = state.openPeriod;
    if (period == null) {
      messenger.showSnackBar(const SnackBar(
        content: Text('No hay un período abierto para declarar.'),
      ));
      return;
    }

    setState(() => _isCreating = true);
    final declaration = await state.createDraft(
      declarant: user,
      period: period,
      superiorUid: superiorUid,
    );
    if (!mounted) return;
    setState(() => _isCreating = false);
    messenger.showSnackBar(SnackBar(
      content: Text(declaration == null
          ? state.errorMessage ?? 'No se pudo crear la declaración.'
          : 'Borrador creado para ${period.name}.'),
    ));
  }

  Future<void> _confirmSignOut() async {
    final auth = context.read<AuthState>();
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Desea salir de su cuenta?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    if (leave == true) await auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthState>().currentUser;
    final state = context.watch<DeclarationState>();
    final isDeclarant = user?.roles.contains(UserRole.declarant) ?? false;
    final open = state.openPeriod;
    final alreadyDeclared = open != null &&
        OnePerPeriod.declarationIn(state.declarations, open.id) != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Declaraciones Juradas'),
        actions: [
          if (user != null)
            IconButton(
              tooltip: 'Cerrar sesión',
              onPressed: _confirmSignOut,
              icon: const Icon(Icons.logout),
            ),
        ],
      ),
      floatingActionButton: isDeclarant && !alreadyDeclared
          ? FloatingActionButton.extended(
              key: const ValueKey<String>('new-declaration'),
              onPressed: _isCreating ? null : _create,
              icon: _isCreating
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add),
              label: const Text('Nueva declaración'),
            )
          : null,
      body: SafeArea(
        child: !isDeclarant
            ? const EmptyState(
                icon: Icons.badge_outlined,
                title: 'Solo para personas declarantes',
                message: 'Este laboratorio muestra el flujo de la persona que '
                    'declara su horario. Su cuenta no tiene ese rol.',
              )
            : _body(context, state, user),
      ),
    );
  }

  Widget _body(BuildContext context, DeclarationState state, AppUser? user) {
    if (state.isLoading && state.declarations.isEmpty) {
      return const LoadingView();
    }
    if (state.listFailed && state.declarations.isEmpty) {
      return ErrorView(
        message: state.errorMessage ?? 'No se pudieron cargar sus declaraciones.',
      );
    }

    final declarations = state.declarations;
    return ListView(
      // Bottom space so the floating button never covers the last card.
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        _SystemHeader(
          userName: user?.fullName ?? '',
          total: declarations.length,
          drafts: declarations
              .where((d) => d.status == DeclarationStatus.borrador)
              .length,
          validated: declarations
              .where((d) => d.status == DeclarationStatus.validada)
              .length,
        ),
        const SizedBox(height: 24),
        Text('Mis declaraciones',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        if (declarations.isEmpty)
          const EmptyState(
            compact: true,
            icon: Icons.description_outlined,
            title: 'Aún no tiene declaraciones',
            message: 'Use «Nueva declaración» para crear la primera.',
          )
        else
          for (final declaration in declarations) ...[
            _DeclarationCard(
              declaration: declaration,
              periodName: _periodName(state.enabledPeriods, declaration),
            ),
            const SizedBox(height: 12),
          ],
      ],
    );
  }

  static String _periodName(List<Period> periods, Declaration declaration) {
    for (final period in periods) {
      if (period.id == declaration.periodId) return period.name;
    }
    return 'Período ${declaration.periodId}';
  }
}

/// Identifies the system and summarizes the declarations by status.
class _SystemHeader extends StatelessWidget {
  const _SystemHeader({
    required this.userName,
    required this.total,
    required this.drafts,
    required this.validated,
  });

  final String userName;
  final int total;
  final int drafts;
  final int validated;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final onPrimary = scheme.onPrimary;

    Widget count(String value, String label) => Expanded(
          child: Column(
            children: [
              Text(value,
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(color: onPrimary)),
              Text(label,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: onPrimary)),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(
                icon: Icons.assignment_turned_in_outlined,
                background: scheme.onPrimary,
                foreground: scheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sistema de Declaraciones Juradas',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(color: onPrimary)),
                    Text('Horario y jornada de trabajo',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: onPrimary)),
                  ],
                ),
              ),
            ],
          ),
          if (userName.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Hola, $userName',
                style:
                    theme.textTheme.bodyMedium?.copyWith(color: onPrimary)),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              count('$total', 'Total'),
              count('$drafts', 'Borradores'),
              count('$validated', 'Validadas'),
            ],
          ),
        ],
      ),
    );
  }
}

/// One declaration: period, version and status with its original name.
class _DeclarationCard extends StatelessWidget {
  const _DeclarationCard({required this.declaration, required this.periodName});

  final Declaration declaration;
  final String periodName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InfoCard(
      // Opens its general data (R2); outside BORRADOR/VALIDADA it is read only.
      onTap: () =>
          context.push(AppRoutes.declarationEditPath(declaration.id)),
      child: Row(
        children: [
          const IconBadge(icon: Icons.description_outlined),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(periodName, style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    StatusChip(status: declaration.status),
                    InfoPill(
                      icon: Icons.layers_outlined,
                      label: 'Versión ${declaration.currentVersionNumber}',
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // The status name of the original system (R1).
                Text(
                  declaration.status.value,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
        ],
      ),
    );
  }
}
