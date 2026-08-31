import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/localization/app_localizations.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/notifications/notification_service.dart';
import 'features/auth/presentation/auth_gate.dart';
import 'features/settings/presentation/settings_controller.dart';

class PakPocketApp extends ConsumerStatefulWidget {
  const PakPocketApp({super.key});

  @override
  ConsumerState<PakPocketApp> createState() => _PakPocketAppState();
}

class _PakPocketAppState extends ConsumerState<PakPocketApp> {
  StreamSubscription<String>? _notificationRoute;

  @override
  void initState() {
    super.initState();
    _notificationRoute = ref
        .read(notificationServiceProvider)
        .routeSelections
        .listen((route) => ref.read(appRouterProvider).go(route));
  }

  @override
  void dispose() {
    _notificationRoute?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsControllerProvider);
    return MaterialApp.router(
      title: 'MeraMarkaz',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: settings.themeMode,
      locale: Locale(settings.languageCode),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: ref.watch(appRouterProvider),
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            boldText: media.boldText,
            highContrast: media.highContrast,
          ),
          child: AuthGate(child: child ?? const SizedBox.shrink()),
        );
      },
    );
  }
}
