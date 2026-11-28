import 'package:flutter/widgets.dart';

import 'app_bootstrap.dart';
import 'core/network/alice_inspector.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AliceInspector.initialize();
  runApp(const AppBootstrap());
}
