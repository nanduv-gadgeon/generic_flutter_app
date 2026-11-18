import 'package:flutter/services.dart';

/// The app is portrait only, on phones and tablets. Info.plist and AndroidManifest.xml say the
/// same, so it never turns during launch either.
Future<void> lockPortrait() => SystemChrome.setPreferredOrientations([
  DeviceOrientation.portraitUp,
  DeviceOrientation.portraitDown,
]);
