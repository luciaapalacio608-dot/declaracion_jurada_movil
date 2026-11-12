import 'dart:io';

import 'package:flutter/services.dart';

/// Loads the real Roboto font (shipped with the Flutter SDK) for widget
/// tests.
///
/// By default tests draw every glyph as a square as wide as the font size,
/// far wider than real text, so overflow checks fail on screens that fit on
/// a real phone. With Roboto, the width is the one the person sees.
Future<void> loadRealFonts() async {
  final fonts = _materialFontsDir();
  final loader = FontLoader('Roboto');
  for (final file in fonts.listSync().whereType<File>()) {
    final name = file.uri.pathSegments.last.toLowerCase();
    if (name.startsWith('roboto') && name.endsWith('.ttf')) {
      final bytes = file.readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
  }
  await loader.load();
}

/// `<flutter>/bin/cache/artifacts/material_fonts`, found from the test
/// runner, which lives under `<flutter>/bin/cache/`.
Directory _materialFontsDir() {
  var dir = File(Platform.resolvedExecutable).parent;
  while (dir.parent.path != dir.path) {
    final candidate = Directory(
        '${dir.path}${Platform.pathSeparator}artifacts'
        '${Platform.pathSeparator}material_fonts');
    if (candidate.existsSync()) return candidate;
    dir = dir.parent;
  }
  throw StateError('Flutter material_fonts not found from '
      '${Platform.resolvedExecutable}');
}
