// Clears the saved Firebase Auth session on web before Firebase starts.
//
// Why: with a saved session, the Firebase Auth web SDK checks it against the
// REAL project as soon as it starts, and after that network call it refuses
// to connect to the Auth emulator. The app then signs in against the real
// project, where the fictitious test accounts do not exist ("Correo o
// contraseña incorrectos"). Only used with USE_EMULATORS=true.
export 'emulator_session_stub.dart'
    if (dart.library.js_interop) 'emulator_session_web.dart';
