// Flutter's desktop Windowing API is intentionally internal while experimental.
// ignore_for_file: implementation_imports, invalid_use_of_internal_member

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/lapse_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runWidget(const ProviderScope(child: LapseWindowHost()));
}
