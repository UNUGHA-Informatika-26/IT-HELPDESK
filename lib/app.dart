import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/ticket_provider.dart';
import 'router.dart';

class HelpdeskApp extends StatefulWidget {
  const HelpdeskApp({super.key});

  @override
  State<HelpdeskApp> createState() => _HelpdeskAppState();
}

class _HelpdeskAppState extends State<HelpdeskApp> {
  late final AuthProvider _authProvider;
  late final TicketProvider _ticketProvider;
  late final router = createAppRouter(_authProvider);

  @override
  void initState() {
    super.initState();
    _authProvider = AuthProvider();
    _ticketProvider = TicketProvider();
  }

  @override
  void dispose() {
    router.dispose();
    _ticketProvider.dispose();
    _authProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: _authProvider),
          ChangeNotifierProvider<TicketProvider>.value(value: _ticketProvider),
        ],
        child: MaterialApp.router(
          title: 'IT Helpdesk',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          routerConfig: router,
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
