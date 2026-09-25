// Équivalent du fichier généré par FlutterFire CLI, écrit à partir de
// `firebase apps:sdkconfig` (apps « moncar_pro » du projet mon-car-a5a97).
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// [FirebaseOptions] de MON CAR PRO (Android + iOS).
///
/// Pas de configuration web : la cible web de l'app PRO ne sert qu'aux
/// démonstrations et Crashlytics n'y est pas disponible.
class DefaultFirebaseOptions {
  /// Vrai si la plateforme courante a une configuration Firebase.
  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCG1IJKQZP91WmTTkrUuQV8py_dkRBhZFQ',
    appId: '1:721652556891:android:97cdd17cb885f84b5a8b7e',
    messagingSenderId: '721652556891',
    projectId: 'mon-car-a5a97',
    storageBucket: 'mon-car-a5a97.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyD3GBnMoGrCUhynUGBMlB0wFP4nPyYIoUY',
    appId: '1:721652556891:ios:e375f49e9d68f1e85a8b7e',
    messagingSenderId: '721652556891',
    projectId: 'mon-car-a5a97',
    storageBucket: 'mon-car-a5a97.firebasestorage.app',
    iosClientId:
        '721652556891-aip9ouap7ffd3a28eg81mpj8s9grave3.apps.googleusercontent.com',
    iosBundleId: 'com.moncar.moncarPro',
  );
}
