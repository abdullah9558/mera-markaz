import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/database/app_database.dart';
import 'core/security/crypto/automatic_local_key_service.dart';
import 'core/theme/app_theme.dart';
import 'features/advanced/data/receipt_repository.dart';
import 'features/auth/data/firebase_auth_repository.dart';
import 'features/auth/domain/auth_session.dart';
import 'features/auth/presentation/auth_controller.dart';
import 'features/expenses/data/finance_export_service.dart';
import 'firebase_options.dart';
import 'shared/presentation/animated_splash.dart';

class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key});

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  _AppDependencies? _dependencies;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
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

    if (mounted) {
      setState(
        () => _dependencies = _AppDependencies(database, authentication),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dependencies = _dependencies;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Theme(
        data: AppTheme.light,
        child: AnimatedSplash(
          complete: dependencies != null,
          child: dependencies == null
              ? const SizedBox.expand()
              : ProviderScope(
                  overrides: [
                    appDatabaseProvider.overrideWithValue(dependencies.database),
                    authRepositoryProvider.overrideWithValue(
                      dependencies.authentication,
                    ),
                  ],
                  child: const PakPocketApp(),
                ),
        ),
      ),
    );
  }
}

class _AppDependencies {
  const _AppDependencies(this.database, this.authentication);

  final AppDatabase database;
  final AuthRepository authentication;
}
