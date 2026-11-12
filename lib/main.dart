import 'package:declara_horario/core/config/app_config.dart';
import 'package:declara_horario/core/config/firebase_emulators.dart';
import 'package:declara_horario/core/config/firebase_not_configured_app.dart';
import 'package:declara_horario/core/config/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app/lab_app.dart';
import 'core/emulator_session.dart';

/// Entry point. Firebase is initialized with DeclaraHorario's own
/// configuration (imported from the package, never copied here), so this
/// lab talks to the same Firebase project and the same data.
///
/// Local data only: `flutter run -d chrome --dart-define=USE_EMULATORS=true`
/// while DeclaraHorario's `npm run emulators` is running.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!AppConfig.isFirebaseConfigured) {
    runApp(const FirebaseNotConfiguredApp());
    return;
  }

  if (FirebaseEmulators.enabled) {
    // A saved session would make Firebase Auth call the real project before
    // the emulator is connected (see emulator_session.dart): sign in again
    // after each reload instead.
    await clearSavedAuthSession();
  }
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (FirebaseEmulators.enabled) {
    await FirebaseEmulators.connect();
  }
  runApp(const LabApp());
}