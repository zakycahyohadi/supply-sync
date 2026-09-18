// Konfigurasi Firebase project retail-insight-e7e4f.
// Dibuat dari `firebase apps:sdkconfig` (format sama dengan hasil
// `flutterfire configure`). Nilai ini bukan rahasia; keamanan data diatur di
// firestore.rules.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions belum dikonfigurasi untuk platform ini.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyA8k1oXS-nZTnr8Yd6Eyo0-v2J_Xup97xI',
    appId: '1:982252233817:web:2d59b4e3b492a5bdcfbd48',
    messagingSenderId: '982252233817',
    projectId: 'retail-insight-e7e4f',
    authDomain: 'retail-insight-e7e4f.firebaseapp.com',
    storageBucket: 'retail-insight-e7e4f.firebasestorage.app',
    measurementId: 'G-L83TT47GFD',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDoBlDZyAiE-KdvVpggmfAFaaqCGBTnpls',
    appId: '1:982252233817:android:ae6bc224cf7a33a3cfbd48',
    messagingSenderId: '982252233817',
    projectId: 'retail-insight-e7e4f',
    storageBucket: 'retail-insight-e7e4f.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBoGmNhBGTcl5fQWiU5Sfz1jkCa4phpIhg',
    appId: '1:982252233817:ios:f55be680113dce2ccfbd48',
    messagingSenderId: '982252233817',
    projectId: 'retail-insight-e7e4f',
    storageBucket: 'retail-insight-e7e4f.firebasestorage.app',
    iosBundleId: 'com.retailinsight.app',
  );
}
