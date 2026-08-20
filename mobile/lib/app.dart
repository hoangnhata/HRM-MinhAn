import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_config.dart';
import 'core/router/app_router.dart';
import 'core/router/app_shell.dart';
import 'core/router/route_paths.dart';
import 'core/sync/live_data_refresh.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/application/auth_controller.dart';
import 'features/auth/application/auth_state.dart';
import 'features/notifications/application/push_notification_service.dart';
import 'features/notifications/presentation/notification_ui.dart';

class HrmMobileApp extends ConsumerStatefulWidget {
  const HrmMobileApp({super.key});

  @override
  ConsumerState<HrmMobileApp> createState() => _HrmMobileAppState();
}

class _HrmMobileAppState extends ConsumerState<HrmMobileApp>
    with WidgetsBindingObserver {
  NotificationTarget? _pendingPushTarget;
  bool _pushBootstrapped = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrapPush());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final live = ref.read(liveDataRefreshProvider);
    if (state == AppLifecycleState.resumed) {
      live.setResumed(true);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      live.setResumed(false);
    }
  }

  Future<void> _bootstrapPush() async {
    if (_pushBootstrapped) return;
    _pushBootstrapped = true;
    // Đảm bảo coordinator gắn listener auth + timer.
    ref.read(liveDataRefreshProvider);
    final push = ref.read(pushNotificationCoordinatorProvider);
    push.onOpen = _onPushOpen;
    push.onInboxRefresh = () async {
      await ref.read(liveDataRefreshProvider).refreshQuietly(force: true);
    };
    await push.initialize();
    final auth = ref.read(authControllerProvider);
    if (auth.status == AuthStatus.authenticated) {
      await push.syncTokenWithBackend();
      unawaited(ref.read(liveDataRefreshProvider).refreshQuietly(force: true));
    }
  }

  void _onPushOpen(NotificationTarget target) {
    final auth = ref.read(authControllerProvider);
    if (auth.status != AuthStatus.authenticated) {
      _pendingPushTarget = target;
      return;
    }
    _navigateTarget(target);
  }

  void _navigateTarget(NotificationTarget target) {
    unawaited(ref.read(liveDataRefreshProvider).refreshQuietly(force: true));
    final router = ref.read(routerProvider);
    if (target.tab != null) {
      ref.read(shellTabProvider.notifier).state = target.tab!;
      router.go(RoutePaths.dashboard);
      return;
    }
    if (target.route != null) {
      router.push(target.route!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    ref.listen<AuthState>(authControllerProvider, (prev, next) async {
      final push = ref.read(pushNotificationCoordinatorProvider);
      final becameAuthed = next.status == AuthStatus.authenticated &&
          prev?.status != AuthStatus.authenticated;
      final becameLoggedOut = next.status == AuthStatus.unauthenticated &&
          prev?.status != AuthStatus.unauthenticated;

      if (becameAuthed) {
        await push.syncTokenWithBackend();
        unawaited(
          ref.read(liveDataRefreshProvider).refreshQuietly(force: true),
        );
        final pending = _pendingPushTarget;
        if (pending != null) {
          _pendingPushTarget = null;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _navigateTarget(pending);
          });
        }
      }
      if (becameLoggedOut) {
        await push.clearTokenOnLogout();
      }
    });

    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
      locale: const Locale('vi'),
      supportedLocales: const [Locale('vi'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
