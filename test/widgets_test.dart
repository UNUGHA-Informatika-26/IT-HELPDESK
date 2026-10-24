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
