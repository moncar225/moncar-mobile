import 'dart:io';

import 'package:flutter/services.dart';

/// Charge la police Roboto du SDK Flutter pour les tests de widgets.
///
/// Par défaut, le moteur de test dessine chaque glyphe comme un carré de
/// 1 em, ce qui double à peu près la largeur des textes et produit de faux
/// débordements. Avec Roboto, les tests détectent les vrais débordements.
Future<void> loadRealFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) return;
  final dir = Directory('$root/bin/cache/artifacts/material_fonts');
  if (!dir.existsSync()) return;

  final roboto = FontLoader('Roboto');
  for (final f in dir.listSync().whereType<File>()) {
    final name = f.uri.pathSegments.last.toLowerCase();
    if (name.startsWith('roboto-') && name.endsWith('.ttf')) {
      roboto.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
    }
  }
  await roboto.load();

  final icons = File('${dir.path}/materialicons-regular.otf');
  if (icons.existsSync()) {
    final loader = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())));
    await loader.load();
  }
}
