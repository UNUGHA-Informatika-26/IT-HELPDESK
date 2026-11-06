import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:it_helpdesk_flutter/core/constants/app_constants.dart';
import 'package:it_helpdesk_flutter/core/theme/app_theme.dart';
import 'package:it_helpdesk_flutter/features/admin/admin_screens.dart';
import 'package:it_helpdesk_flutter/features/auth/auth_screens.dart';
import 'package:it_helpdesk_flutter/features/employee/employee_screens.dart';
import 'package:it_helpdesk_flutter/models/app_user.dart';
import 'package:it_helpdesk_flutter/models/ticket.dart';
import 'package:it_helpdesk_flutter/providers/auth_provider.dart';
import 'package:it_helpdesk_flutter/providers/ticket_provider.dart';
import 'package:it_helpdesk_flutter/services/ticket_service.dart';
import 'package:it_helpdesk_flutter/widgets/helpdesk_widgets.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

class _MockFirestore extends Mock implements FirebaseFirestore {}

class _TestTicketService extends TicketService {
  _TestTicketService(this.ticket) : super(firestore: _MockFirestore());

  final Ticket ticket;

  @override
  Stream<List<Ticket>> watchTickets({
    required String? userId,
    required String? companyId,
  }) =>
      Stream.value([]);

  @override
  Stream<Ticket?> watchTicket(String id) => Stream.value(ticket);

  @override
  Future<int> countTickets({
    required String? userId,
    required String? companyId,
    required String status,
  }) async =>
      0;
}

class _FailingCountTicketService extends _TestTicketService {
  _FailingCountTicketService(super.ticket);

  @override
  Future<int> countTickets({
    required String? userId,
    required String? companyId,
    required String status,
  }) async {
    throw FirebaseException(
      plugin: 'cloud_firestore',
      message: 'UNAVAILABLE',
    );
  }
}

Ticket _ticket({String status = TicketStatuses.waiting}) => Ticket(
      id: 'a1b2c3ticket',
      ticketNumber: 'HD-A1B2C3',
      title: 'Printer tidak bisa mencetak',
      description: 'Printer ruang operasional tidak merespons.',
      category: TicketCategories.printer,
      priority: TicketPriorities.urgent,
      status: status,
      userId: 'user-1',
      userName: 'Ayu Lestari',
      companyId: 'company-1',
      createdAt: DateTime(2026, 6, 24, 9, 42),
      updatedAt: DateTime(2026, 6, 24, 9, 42),
    );

AppUser _user({bool isAdmin = false}) => AppUser(
      uid: 'user-1',
      name: 'Ayu Lestari',
      email: 'ayu@gmail.com',
      role: isAdmin ? UserRoles.admin : UserRoles.employee,
      companyId: 'company-1',
      companyCode: 'IT001',
      status: AccountStatuses.active,
      department: 'Operasional',
    );

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  test('loadCounts stores a connection error when Firestore is unavailable',
      () async {
    final provider = TicketProvider(
      ticketService: _FailingCountTicketService(_ticket()),
    );
    addTearDown(provider.dispose);

    await expectLater(provider.loadCounts(_user()), completes);

    expect(
      provider.countsError,
      'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.',
    );
  });

  testWidgets('logging out from Profile does not throw during rebuild',
      (tester) async {
    final authProvider = AuthProvider.forTesting(user: _user());
    final router = GoRouter(
      initialLocation: AppRoutes.employeeProfile,
      routes: [
        GoRoute(
          path: AppRoutes.employeeProfile,
          builder: (context, state) => const ProfileScreen(isAdmin: false),
        ),
        GoRoute(
          path: AppRoutes.login,
          builder: (context, state) => const Scaffold(body: Text('Login')),
        ),
      ],
    );
    addTearDown(authProvider.dispose);
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider(
            create: (_) => TicketProvider(
              ticketService: _TestTicketService(_ticket()),
            ),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(ListView), const Offset(0, -1000));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keluar dari akun'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ya, Keluar'));
    await tester.pumpAndSettle();

    expect(find.text('Login'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Onboarding fits normal screens and scrolls on short screens',
      (tester) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    for (final (size, textScale) in [
      (const Size(360, 640), 1.0),
      (const Size(400, 498), 1.0),
      (const Size(400, 498), 1.5),
    ]) {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: const OnboardingScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Laporkan kendala dengan mudah'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Login shows a required-field message for empty inputs',
      (tester) async {
    final authProvider = AuthProvider.forTesting();
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: authProvider,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const LoginScreen(),
        ),
      ),
    );

    await tester.tap(find.text('Masuk'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Email wajib diisi.'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('login-email')),
      'ayu@gmail.com',
    );
    await tester.pump();
    expect(find.byType(AlertBanner), findsNothing);
    authProvider.dispose();
  });

  testWidgets('Login rejects an invalid email format', (tester) async {
    final authProvider = AuthProvider.forTesting();
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: authProvider,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const LoginScreen(),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('login-email')),
      'invalid-email',
    );
    await tester.enterText(
      find.byKey(const ValueKey('login-password')),
      'password',
    );
    await tester.tap(find.text('Masuk'));
    await tester.pumpAndSettle();

    expect(find.text('Format email tidak valid.'), findsOneWidget);
    authProvider.dispose();
  });

  testWidgets('Login password visibility toggles without losing input or focus',
      (tester) async {
    final authProvider = AuthProvider.forTesting();
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: authProvider,
        child: const MaterialApp(home: LoginScreen()),
      ),
    );

    final passwordFinder = find.byKey(const ValueKey('login-password'));
    bool isObscured() => tester
        .widget<EditableText>(
          find.descendant(
            of: passwordFinder,
            matching: find.byType(EditableText),
          ),
        )
        .obscureText;

    await tester.enterText(passwordFinder, 'my-password');
    final controller = tester.widget<TextFormField>(passwordFinder).controller!;
    final selection = controller.selection;
    expect(isObscured(), isTrue);
    expect(
      tester
          .widget<EditableText>(find.descendant(
            of: passwordFinder,
            matching: find.byType(EditableText),
          ))
          .focusNode
          .hasFocus,
      isTrue,
    );

    await tester.tap(
      find.descendant(
        of: passwordFinder,
        matching: find.byTooltip('Tampilkan password'),
      ),
    );
    await tester.pump();

    expect(isObscured(), isFalse);
    expect(controller.text, 'my-password');
    expect(controller.selection, selection);
    expect(
      tester
          .widget<EditableText>(find.descendant(
            of: passwordFinder,
            matching: find.byType(EditableText),
          ))
          .focusNode
          .hasFocus,
      isTrue,
    );

    await tester.tap(
      find.descendant(
        of: passwordFinder,
        matching: find.byTooltip('Sembunyikan password'),
      ),
    );
    await tester.pump();
    expect(isObscured(), isTrue);
    authProvider.dispose();
  });

  testWidgets('Registration password fields toggle independently',
      (tester) async {
    final authProvider = AuthProvider.forTesting();
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: authProvider,
        child: const MaterialApp(home: RegisterEmployeeScreen()),
      ),
    );

    final passwordFinder = find.byKey(const ValueKey('register-password'));
    final confirmFinder =
        find.byKey(const ValueKey('register-confirm-password'));
    bool isObscured(Finder fieldFinder) => tester
        .widget<EditableText>(
          find.descendant(
            of: fieldFinder,
            matching: find.byType(EditableText),
          ),
        )
        .obscureText;

    await tester.enterText(passwordFinder, 'employee-password');
    await tester.enterText(confirmFinder, 'employee-password');

    expect(isObscured(passwordFinder), isTrue);
    expect(isObscured(confirmFinder), isTrue);
    await tester.tap(
      find.descendant(
        of: passwordFinder,
        matching: find.byTooltip('Tampilkan password'),
      ),
    );
    await tester.pump();

    expect(isObscured(passwordFinder), isFalse);
    expect(isObscured(confirmFinder), isTrue);
    await tester.tap(
      find.descendant(
        of: confirmFinder,
        matching: find.byTooltip('Tampilkan password'),
      ),
    );
    await tester.pump();

    expect(isObscured(confirmFinder), isFalse);
    expect(isObscured(passwordFinder), isFalse);
    await tester.tap(
      find.descendant(
        of: passwordFinder,
        matching: find.byTooltip('Sembunyikan password'),
      ),
    );
    await tester.pump();
    expect(isObscured(passwordFinder), isTrue);
    expect(isObscured(confirmFinder), isFalse);
    authProvider.dispose();
  });

  testWidgets('Login and registration use the Email label', (tester) async {
    final authProvider = AuthProvider.forTesting();
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: authProvider,
        child: const MaterialApp(home: LoginScreen()),
      ),
    );

    expect(find.text('Email *'), findsOneWidget);

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: authProvider,
        child: const MaterialApp(home: RegisterEmployeeScreen()),
      ),
    );
    expect(find.text('Email *'), findsOneWidget);
    authProvider.dispose();
  });

  testWidgets('AlertBanner variants share dimensions and show their message',
      (tester) async {
    const variants = AlertBannerVariant.values;
    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            for (final variant in variants)
              AlertBanner(message: 'Pesan', variant: variant),
          ],
        ),
      ),
    );

    final banners = tester.widgetList<AlertBanner>(find.byType(AlertBanner));
    expect(banners, hasLength(3));
    final containers = tester
        .widgetList<Container>(
          find.descendant(
            of: find.byType(AlertBanner),
            matching: find.byType(Container),
          ),
        )
        .toList();
    expect(containers, hasLength(3));
    expect(
        containers.map((container) => container.padding).toSet(), hasLength(1));
    expect(
      containers
          .map((container) =>
              (container.decoration! as BoxDecoration).borderRadius)
          .toSet(),
      hasLength(1),
    );
    expect(find.text('Pesan'), findsNWidgets(3));
  });

  testWidgets('confirmation dialog actions are side by side and equal width',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showConfirmDialog(
                context: context,
                title: 'Konfirmasi',
                content: const Text('Lanjutkan?'),
                confirmLabel: 'Ya, Lanjutkan',
              ),
              child: const Text('Buka dialog'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Buka dialog'));
    await tester.pumpAndSettle();

    final cancel = tester.getRect(find.byType(OutlinedButton));
    final confirm = tester.getRect(find.byType(FilledButton));
    expect(cancel.center.dy, confirm.center.dy);
    expect(cancel.width, moreOrLessEquals(confirm.width));
    expect(cancel.left, lessThan(confirm.left));
  });

  testWidgets('employee and admin bottom navigation track each active tab',
      (tester) async {
    for (final (isAdmin, paths, labels) in [
      (
        false,
        [
          AppRoutes.employeeHome,
          AppRoutes.employeeTickets,
          AppRoutes.employeeProfile,
        ],
        ['Beranda', 'Tiket Saya', 'Profil'],
      ),
      (
        true,
        [
          AppRoutes.adminHome,
          AppRoutes.adminTickets,
          AppRoutes.reports,
          AppRoutes.adminProfile,
        ],
        ['Dashboard', 'Semua Tiket', 'Laporan', 'Profil'],
      ),
    ]) {
      final router = GoRouter(
        initialLocation: paths.first,
        routes: [
          for (final path in paths)
            GoRoute(
              path: path,
              builder: (context, state) => Scaffold(
                bottomNavigationBar: TicketBottomNavigation(isAdmin: isAdmin),
              ),
            ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      for (var index = 0; index < labels.length; index++) {
        await tester.tap(find.text(labels[index]));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<NavigationBar>(find.byType(NavigationBar))
              .selectedIndex,
          index,
        );
      }
    }
  });

  testWidgets('employee and admin status filters default to Semua',
      (tester) async {
    for (final isAdmin in [false, true]) {
      final path = isAdmin ? AppRoutes.adminTickets : AppRoutes.employeeTickets;
      final ticketProvider =
          TicketProvider(ticketService: _TestTicketService(_ticket()));
      final authProvider =
          AuthProvider.forTesting(user: _user(isAdmin: isAdmin));
      final router = GoRouter(
        initialLocation: path,
        routes: [
          GoRoute(
            path: path,
            builder: (context, state) => isAdmin
                ? const AdminTicketsScreen()
                : const EmployeeTicketsScreen(),
          ),
        ],
      );
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<TicketProvider>.value(
              value: ticketProvider,
            ),
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(
          tester.widgetList<ChoiceChip>(find.byType(ChoiceChip)).first.selected,
          isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
      ticketProvider.dispose();
      authProvider.dispose();
    }
  });

  testWidgets('ticket create and edit dropdowns use ticket values',
      (tester) async {
    final ticketProvider =
        TicketProvider(ticketService: _TestTicketService(_ticket()));
    final authProvider = AuthProvider.forTesting(user: _user());
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<TicketProvider>.value(value: ticketProvider),
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ],
        child: const MaterialApp(home: CreateTicketScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byKey(const ValueKey('ticket-category')),
          )
          .initialValue,
      TicketCategories.computer,
    );
    expect(
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byKey(const ValueKey('ticket-priority')),
          )
          .initialValue,
      TicketPriorities.normal,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<TicketProvider>.value(value: ticketProvider),
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ],
        child: const MaterialApp(
          home: EditTicketScreen(ticketId: 'a1b2c3ticket'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final fields = tester.widgetList<DropdownButtonFormField<String>>(
      find.byType(DropdownButtonFormField<String>),
    );
    expect(fields.first.initialValue, TicketCategories.printer);
    expect(fields.last.initialValue, TicketPriorities.urgent);
    ticketProvider.dispose();
    authProvider.dispose();
  });

  testWidgets('StatusChip displays the selected status', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: StatusChip(status: TicketStatuses.inProgress)),
    );

    expect(find.text(TicketStatuses.inProgress), findsOneWidget);
  });

  testWidgets('TicketCard displays its title and ticket number',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TicketCard(ticket: _ticket())),
      ),
    );

    expect(find.text('Printer tidak bisa mencetak'), findsOneWidget);
    expect(find.text('HD-A1B2C3'), findsOneWidget);
    final card = tester.getRect(find.byType(Card));
    final chevron = tester.getRect(find.byIcon(Icons.chevron_right));
    expect(chevron.center.dy, closeTo(card.center.dy, 1));
    expect(chevron.right, closeTo(card.right - 15, 2));
  });

  testWidgets('PriorityBadge supports CITO, Segera, and Biasa', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Row(
          children: [
            PriorityBadge(priority: TicketPriorities.emergency),
            PriorityBadge(priority: TicketPriorities.urgent),
            PriorityBadge(priority: TicketPriorities.normal),
          ],
        ),
      ),
    );

    for (final priority in TicketPriorities.all) {
      expect(find.text(priority), findsOneWidget);
    }
  });

  testWidgets('Edit and Batalkan only appear for an owned waiting ticket',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TicketPermissionActions(
            ticket: _ticket(),
            isAdmin: false,
            isOwner: true,
            onEdit: () {},
            onCancel: () {},
            adminActionBuilder: () => const Text('Tindakan admin'),
          ),
        ),
      ),
    );

    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Batalkan'), findsOneWidget);
    expect(find.text('Hapus tiket'), findsNothing);
    final buttons = find.byType(OutlinedButton);
    expect(tester.widgetList<OutlinedButton>(buttons), hasLength(2));
    expect(tester.getRect(buttons.at(0)).height, 48);
    expect(tester.getRect(buttons.at(1)).height, 48);
  });

  testWidgets('Edit and Batalkan are hidden for non-waiting tickets',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TicketPermissionActions(
            ticket: _ticket(status: TicketStatuses.inProgress),
            isAdmin: false,
            isOwner: true,
            onEdit: () {},
            onCancel: () {},
            adminActionBuilder: () => const Text('Tindakan admin'),
          ),
        ),
      ),
    );

    expect(find.text('Edit'), findsNothing);
    expect(find.text('Batalkan'), findsNothing);
    expect(find.text('Hapus tiket'), findsNothing);
  });

  testWidgets('Cancelled admin tickets show no status action panel',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TicketPermissionActions(
            ticket: _ticket(status: TicketStatuses.cancelled),
            isAdmin: true,
            isOwner: false,
            onEdit: () {},
            onCancel: () {},
            adminActionBuilder: () => const Text('Tindakan admin'),
          ),
        ),
      ),
    );

    expect(find.text('Tiket telah dibatalkan'), findsOneWidget);
    expect(find.text('Tindakan admin'), findsNothing);
    expect(find.text('Hapus tiket'), findsNothing);
  });
}
