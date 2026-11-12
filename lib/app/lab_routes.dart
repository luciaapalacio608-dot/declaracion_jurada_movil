import 'package:declara_horario/core/routing/app_routes.dart';

/// Paths of the lab's own screens.
///
/// The lab reuses DeclaraHorario's paths (and therefore its RouteGuard)
/// wherever a screen plays the same role: `/declarations` is the main
/// screen, `/declarations/:id/edit` the form. The schedule and the summary are new.
class LabRoutes {
  const LabRoutes._();

  /// Main screen: the declarant's declarations (R1).
  static const String home = AppRoutes.declarations;

  /// Summary of one declaration (R6); build it with [summaryPath].
  static const String summary =
      '/declarations/:${AppRoutes.declarationIdParam}/summary';

  /// Weekly schedule of one declaration (R3/R4); build it with
  /// [schedulePath].
  static const String schedule =
      '/declarations/:${AppRoutes.declarationIdParam}/schedule';

  /// Concrete path of [schedule] for declaration [id].
  static String schedulePath(String id) => '/declarations/$id/schedule';

  /// Concrete path of [summary] for declaration [id].
  static String summaryPath(String id) => '/declarations/$id/summary';
}
