import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/platform/orientation.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await lockPortrait();
  runApp(const ProviderScope(child: GenericApp()));
}
