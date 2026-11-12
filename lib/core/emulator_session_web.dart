import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Deletes the Firebase Auth session saved in this browser (IndexedDB
/// `firebaseLocalStorageDb` and any `firebase:` key in localStorage), so the
/// emulator can be connected before any network call.
Future<void> clearSavedAuthSession() async {
  final storage = web.window.localStorage;
  for (var i = storage.length - 1; i >= 0; i--) {
    final key = storage.key(i);
    if (key != null && key.startsWith('firebase:')) storage.removeItem(key);
  }
  final done = Completer<void>();
  final request = web.window.indexedDB.deleteDatabase('firebaseLocalStorageDb');
  void finish(web.Event _) {
    if (!done.isCompleted) done.complete();
  }

  request.onsuccess = finish.toJS;
  request.onerror = finish.toJS;
  request.onblocked = finish.toJS;
  await done.future.timeout(const Duration(seconds: 3), onTimeout: () {});
}
