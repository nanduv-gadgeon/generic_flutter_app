import 'package:flutter/services.dart';

/// The app is portrait only (either way up), never landscape, on phones and tablets.
/// Info.plist and AndroidManifest.xml say the same, so it never turns during launch either.
Future<void> lockPortrait() => SystemChrome.setPreferredOrientations([
  DeviceOrientation.portraitUp,
  DeviceOrientation.portraitDown,
]);
