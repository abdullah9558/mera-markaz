import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'app.dart';
import 'core/database/app_database.dart';
import 'core/security/crypto/automatic_local_key_service.dart';
import 'features/auth/data/firebase_auth_repository.dart';
import 'features/expenses/data/finance_export_service.dart';
import 'features/auth/domain/auth_session.dart';
import 'features/auth/presentation/auth_controller.dart';
import 'firebase_options.dart';
import 'features/advanced/data/receipt_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PlaintextExportCleaner.removeTemporaryExports();
  final database = AppDatabase();
  final databasePassword = defaultTargetPlatform == TargetPlatform.android
      ? await AutomaticLocalKeyService().databasePassword()
      : null;
  await database.open(encryptionPassword: databasePassword);
  if (databasePassword != null) {
    await ReceiptFileMigrationService(database).migrateLegacyFiles();
  }
  AuthRepository authentication = const UnconfiguredAuthRepository();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kReleaseMode
          ? const AndroidPlayIntegrityProvider()
          : const AndroidDebugProvider(),
    );
    if (!kReleaseMode) {
      try {
        await FirebaseAppCheck.instance.getToken(true);
      } catch (error) {
        debugPrint('Firebase App Check debug token request: $error');
      }
    }
    authentication = FirebaseAuthRepository();
  } catch (_) {
    // Online authentication remains unavailable until Firebase is configured.
  }
  runApp(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        authRepositoryProvider.overrideWithValue(authentication),
      ],
      child: const PakPocketApp(),
    ),
  );
}
