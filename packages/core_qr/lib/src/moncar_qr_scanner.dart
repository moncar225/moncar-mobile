import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Scanner QR MON CAR (billets électroniques, dépôt/retrait de colis).
///
/// [onDetect] est appelé pour chaque code détecté ; c'est à l'appelant de
/// filtrer le contenu et d'arrêter le scan (pop de l'écran) après un succès.
class MoncarQrScanner extends StatelessWidget {
  const MoncarQrScanner({
    super.key,
    required this.onDetect,
    this.title,
    this.helpText,
  });

  final ValueChanged<BarcodeCapture> onDetect;

  /// Titre affiché dans l'app bar du scanner.
  final String? title;

  /// Consigne affichée en surimpression (ex. « Présentez votre billet »).
  final String? helpText;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title ?? 'Scanner un code QR')),
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(onDetect: onDetect),
          if (helpText != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  helpText!,
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
