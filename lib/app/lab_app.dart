import 'package:declara_horario/core/config/app_providers.dart';
import 'package:declara_horario/core/config/session_scope.dart';
import 'package:declara_horario/core/theme/app_theme.dart';
import 'package:declara_horario/core/theme/theme_state.dart';
import 'package:declara_horario/features/auth/state/auth_state.dart';
import 'package:declara_horario/shared/widgets/loading_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'lab_router.dart';

/// Root of the lab app.
///
/// Everything below the screens is DeclaraHorario's: the providers
/// (repositories, services and the session in [AuthState]), the session
/// states ([SessionScope]) and the UCR theme ([AppTheme]). The lab only adds
/// its own router and mobile screens.
class LabApp extends StatelessWidget {
  const LabApp({super.key});

  /// Name of the system shown in the browser tab.
  static const String title = 'Declaraciones Juradas';

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: buildAppProviders(),
      child: const _LabView(),
    );
  }
}

class _LabView extends StatefulWidget {
  const _LabView();

  @override
  State<_LabView> createState() => _LabViewState();
}

class _LabViewState extends State<_LabView> {
  /// Created once: recreating it on every rebuild would reset navigation.
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = LabRouter.create(context.read<AuthState>());
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<ThemeState>().themeMode;
    final isInitializing =
        context.select<AuthState, bool>((auth) => auth.isInitializing);

    // Nothing is shown until the session is known, so the login screen does
    // not flash before a signed-in user's declarations.
    if (isInitializing) {
      return MaterialApp(
        title: LabApp.title,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        home: const Scaffold(body: LoadingView()),
      );
    }

    return MaterialApp.router(
      title: LabApp.title,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: _router,
      // Pickers and dialogs in Spanish (Costa Rica), 24-hour clock.
      locale: const Locale('es', 'CR'),
      supportedLocales: const [Locale('es', 'CR'), Locale('es')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) =>
          SessionScope(child: child ?? const SizedBox.shrink()),
    );
  }
}
