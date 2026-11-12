import 'package:declara_horario/core/theme/app_theme.dart';
import 'package:declara_horario/features/auth/screens/login_screen.dart';
import 'package:declara_horario/features/auth/state/auth_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'support/auth_fakes.dart';
import 'support/real_fonts.dart';

/// The lab reuses DeclaraHorario's sign-in screen as is; this checks it fits
/// a small phone without horizontal overflow.
void main() {
  setUpAll(loadRealFonts);

  // 360 dp is the narrowest common Android width; 412 dp a typical one.
  // At 320 dp DeclaraHorario's "¿No tienes cuenta? · Crear cuenta" row
  // overflows by 17 px; that screen is reused as is (not modified).
  for (final size in <Size>[const Size(360, 640), const Size(412, 915)]) {
    testWidgets(
        'login fits a ${size.width.toInt()}x${size.height.toInt()} phone',
        (tester) async {
      tester.view.physicalSize = size * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthState>.value(
          value: signedOutAuthState(),
          child: MaterialApp(theme: AppTheme.light, home: const LoginScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // A RenderFlex overflow is reported as an exception in tests.
      expect(tester.takeException(), isNull);
      expect(find.byType(TextField), findsWidgets);
    });
  }
}
