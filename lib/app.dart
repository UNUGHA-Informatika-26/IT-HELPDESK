import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'core/constants/app_constants.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'features/connectivity/connectivity_cubit.dart';
import 'providers/auth_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/ticket_provider.dart';
import 'router.dart';

class HelpdeskApp extends StatefulWidget {
  const HelpdeskApp({super.key});

  @override
  State<HelpdeskApp> createState() => _HelpdeskAppState();
}

class _HelpdeskAppState extends State<HelpdeskApp> with WidgetsBindingObserver {
  late final AuthProvider _authProvider;
  late final TicketProvider _ticketProvider;
  late final NotificationProvider _notificationProvider;
  late final ConnectivityCubit _connectivityCubit;
  late final StreamSubscription<ConnectivityStatus> _connectivitySubscription;
  late final router = createAppRouter(_authProvider);
  String? _managedUid;

  @override
  void initState() {
    super.initState();
    _authProvider = AuthProvider();
    _ticketProvider = TicketProvider();
    _connectivityCubit = ConnectivityCubit();
    _notificationProvider = NotificationProvider(authProvider: _authProvider);
    WidgetsBinding.instance.addObserver(this);
    _authProvider.addListener(_syncAuthenticatedUser);
    _ticketProvider.addListener(_syncFirestoreConnectivity);
    _connectivitySubscription =
        _connectivityCubit.stream.listen((_) => _syncConnectionState());
    _syncConnectionState();
  }

  void _syncConnectionState() {
    _ticketProvider.setConnectivity(_connectivityCubit.state);
  }

  void _syncFirestoreConnectivity() {
    if (_ticketProvider.isOffline && _connectivityCubit.isOnline) {
      _connectivityCubit.reportFirestoreUnavailable();
    }
  }

  void _syncAuthenticatedUser() {
    if (_authProvider.isChecking) return;
    final user = _authProvider.user;
    if (user == null) {
      final previousUid = _managedUid;
      _managedUid = null;
      if (previousUid != null) {
        unawaited(_ticketProvider.clearUserData(previousUid));
      }
      return;
    }
    if (_managedUid == user.uid) return;
    final previousUid = _managedUid;
    _managedUid = user.uid;
    if (previousUid != null) {
      unawaited(_ticketProvider.clearUserData(previousUid));
    }
    unawaited(_ticketProvider.activateUser(user));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    unawaited(_connectivityCubit.refresh());
    final user = _authProvider.user;
    if (user != null) {
      unawaited(_ticketProvider.refreshTickets(user));
      unawaited(_ticketProvider.syncOutbox(uid: user.uid));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authProvider.removeListener(_syncAuthenticatedUser);
    _ticketProvider.removeListener(_syncFirestoreConnectivity);
    _connectivitySubscription.cancel();
    router.dispose();
    _notificationProvider.dispose();
    _ticketProvider.dispose();
    _connectivityCubit.close();
    _authProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: _authProvider),
          ChangeNotifierProvider<TicketProvider>.value(value: _ticketProvider),
          ChangeNotifierProvider<NotificationProvider>.value(
            value: _notificationProvider,
          ),
          BlocProvider<ConnectivityCubit>.value(value: _connectivityCubit),
        ],
        child: MaterialApp.router(
          title: 'IT Helpdesk',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          routerConfig: router,
          builder: (context, child) => _AppBackHandler(child: child!),
          locale: const Locale('id', 'ID'),
          supportedLocales: const [Locale('id', 'ID')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        ),
      );
}

class _AppBackHandler extends StatelessWidget {
  const _AppBackHandler({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final router = GoRouter.of(context);
    final path = router.routeInformationProvider.value.uri.path;
    final isTab = {
      AppRoutes.employeeTickets,
      AppRoutes.employeeProfile,
      AppRoutes.adminTickets,
      AppRoutes.reports,
      AppRoutes.adminProfile,
    }.contains(path);
    return PopScope<Object?>(
      canPop: router.canPop() && !isTab,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_handleBack(context, path));
      },
      child: child,
    );
  }

  Future<void> _handleBack(BuildContext context, String path) async {
    if (path == AppRoutes.createTicket ||
        path.startsWith('/employee/tickets/') && path.endsWith('/edit')) {
      return;
    }
    final isHome =
        path == AppRoutes.employeeHome || path == AppRoutes.adminHome;
    if (isHome ||
        path == AppRoutes.login ||
        path == AppRoutes.splash ||
        path == AppRoutes.onboarding ||
        path == AppRoutes.register ||
        path == AppRoutes.resetPassword) {
      return;
    }
    final auth = context.read<AuthProvider>();
    final home = auth.user?.isAdmin == true
        ? AppRoutes.adminHome
        : AppRoutes.employeeHome;
    if ({
      AppRoutes.employeeTickets,
      AppRoutes.employeeProfile,
      AppRoutes.adminTickets,
      AppRoutes.reports,
      AppRoutes.adminProfile,
    }.contains(path)) {
      context.go(home);
    } else if (GoRouter.of(context).canPop()) {
      context.pop();
    } else {
      context.go(
        auth.user?.isAdmin == true
            ? AppRoutes.adminTickets
            : AppRoutes.employeeTickets,
      );
    }
  }
}
