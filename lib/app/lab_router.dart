import 'package:declara_horario/core/routing/app_routes.dart';
import 'package:declara_horario/core/routing/route_guard.dart';
import 'package:declara_horario/features/auth/auth_routes.dart';
import 'package:declara_horario/features/auth/state/auth_state.dart';
import 'package:go_router/go_router.dart';

import '../screens/formulario_screen.dart';
import '../screens/home_screen.dart';
import '../screens/horarios_screen.dart';
import '../screens/resumen_screen.dart';
import '../screens/not_found_screen.dart';
import 'lab_routes.dart';

/// Router of the lab.
///
/// Sign-in, sign-up, email verification, "Completa tu perfil" and profile
/// are DeclaraHorario's own screens ([authRoutes]), and so is the access
/// logic ([RouteGuard]). The only difference: where DeclaraHorario sends a
/// signed-in user to its role picker, the lab opens its own main screen.
class LabRouter {
  const LabRouter._();

  /// Router that re-evaluates the redirect whenever the session changes.
  static GoRouter create(AuthState authState) => GoRouter(
        initialLocation: AppRoutes.login,
        refreshListenable: authState,
        redirect: (context, state) => redirect(
          authState: authState,
          location: state.matchedLocation,
        ),
        routes: routes(),
        errorBuilder: (context, state) => const NotFoundScreen(),
      );

  /// Every registered route.
  static List<RouteBase> routes() => <RouteBase>[
        // DeclaraHorario's role picker is replaced by the lab's main screen.
        ...authRoutes().where(
          (route) => route is! GoRoute || route.path != AppRoutes.home,
        ),
        GoRoute(
          path: LabRoutes.home,
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: AppRoutes.declarationEdit,
          builder: (context, state) => FormularioScreen(
            declarationId: state.pathParameters[AppRoutes.declarationIdParam]!,
          ),
        ),
        GoRoute(
          path: LabRoutes.schedule,
          builder: (context, state) => HorariosScreen(
            declarationId: state.pathParameters[AppRoutes.declarationIdParam]!,
          ),
        ),
        GoRoute(
          path: LabRoutes.summary,
          builder: (context, state) => ResumenScreen(
            declarationId: state.pathParameters[AppRoutes.declarationIdParam]!,
          ),
        ),
      ];

  /// [RouteGuard.redirect], landing on [LabRoutes.home] instead of the role
  /// picker.
  static String? redirect({
    required AuthState authState,
    required String location,
  }) {
    if (location == AppRoutes.home && authState.currentUser != null) {
      return LabRoutes.home;
    }
    final target =
        RouteGuard.redirect(authState: authState, location: location);
    if (target == AppRoutes.home) {
      return location == LabRoutes.home ? null : LabRoutes.home;
    }
    return target;
  }
}
