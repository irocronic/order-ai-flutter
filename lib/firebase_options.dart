// lib/firebase_options.dart
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
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDK2D-Hn6T8mRFHiUzO9keUWtoAgDLqZPI',
    appId: '1:868285110583:web:79bd76d003b1ed7464a2b2',
    messagingSenderId: '868285110583',
    projectId: 'makarnaappfirebase',
    authDomain: 'makarnaappfirebase.firebaseapp.com',
    storageBucket: 'makarnaappfirebase.firebasestorage.app',
    measurementId: 'G-MDBHQDW6ZV',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCAVns-BUU72xfQYverQWe1OnR7xl_8zvc',
    appId: '1:868285110583:android:b40e9ef9fb3782ca64a2b2',
    messagingSenderId: '868285110583',
    projectId: 'makarnaappfirebase',
    storageBucket: 'makarnaappfirebase.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBmOlIdHCe3TtzgNANRB9GjvTJ7KUAnwIM',
    appId: '1:868285110583:ios:70e6cedeaa96c34964a2b2',
    messagingSenderId: '868285110583',
    projectId: 'makarnaappfirebase',
    storageBucket: 'makarnaappfirebase.firebasestorage.app',
    iosBundleId: 'com.example.makarnaApp',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyBmOlIdHCe3TtzgNANRB9GjvTJ7KUAnwIM',
    appId: '1:868285110583:ios:70e6cedeaa96c34964a2b2',
    messagingSenderId: '868285110583',
    projectId: 'makarnaappfirebase',
    storageBucket: 'makarnaappfirebase.firebasestorage.app',
    iosBundleId: 'com.example.makarnaApp',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyDK2D-Hn6T8mRFHiUzO9keUWtoAgDLqZPI',
    appId: '1:868285110583:web:a41bd4c052ce2e9564a2b2',
    messagingSenderId: '868285110583',
    projectId: 'makarnaappfirebase',
    authDomain: 'makarnaappfirebase.firebaseapp.com',
    storageBucket: 'makarnaappfirebase.firebasestorage.app',
    measurementId: 'G-S8W4MP9DLJ',
  );
}
