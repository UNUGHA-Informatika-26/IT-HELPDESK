import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:it_helpdesk_flutter/core/constants/app_constants.dart';
import 'package:it_helpdesk_flutter/core/theme/app_theme.dart';
import 'package:it_helpdesk_flutter/features/auth/auth_screens.dart';
import 'package:it_helpdesk_flutter/models/ticket.dart';
import 'package:it_helpdesk_flutter/providers/auth_provider.dart';
import 'package:it_helpdesk_flutter/widgets/helpdesk_widgets.dart';
import 'package:provider/provider.dart';

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

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

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

    expect(find.text('Email wajib diisi.'), findsOneWidget);
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

    expect(find.text('Email'), findsOneWidget);

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: authProvider,
        child: const MaterialApp(home: RegisterEmployeeScreen()),
      ),
    );
    expect(find.text('Email'), findsOneWidget);
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
