import 'package:flutter_test/flutter_test.dart';
import 'package:it_helpdesk_flutter/core/constants/app_constants.dart';
import 'package:it_helpdesk_flutter/models/app_user.dart';
import 'package:it_helpdesk_flutter/models/ticket.dart';

void main() {
  group('AppUser serialization', () {
    test('round-trips the profile map', () {
      final original = AppUser(
        uid: 'user-1',
        name: 'Ayu Lestari',
        email: 'ayu@example.com',
        role: UserRoles.employee,
        companyId: 'company-1',
        companyCode: 'ABC123',
        status: AccountStatuses.active,
        department: 'Operasional',
        createdAt: DateTime.utc(2026, 1, 2, 3, 4),
      );

      final restored = AppUser.fromMap(original.uid, original.toMap());

      expect(restored.uid, original.uid);
      expect(restored.name, original.name);
      expect(restored.email, original.email);
      expect(restored.role, original.role);
      expect(restored.companyId, original.companyId);
      expect(restored.companyCode, original.companyCode);
      expect(restored.status, original.status);
      expect(restored.department, original.department);
      expect(restored.createdAt, original.createdAt);
    });
  });

  group('Ticket serialization', () {
    test('round-trips ticket data and document ID', () {
      final original = Ticket(
        id: 'a1b2c3ticket',
        ticketNumber: 'HD-A1B2C3',
        title: 'Printer tidak merespons',
        description: 'Printer lantai dua tidak dapat mencetak.',
        category: TicketCategories.printer,
        priority: TicketPriorities.urgent,
        status: TicketStatuses.waiting,
        userId: 'user-1',
        userName: 'Ayu Lestari',
        companyId: 'company-1',
        createdAt: DateTime.utc(2026, 1, 2),
        updatedAt: DateTime.utc(2026, 1, 2, 1),
        resolvedAt: null,
      );

      final restored = Ticket.fromMap(original.id, original.toMap());

      expect(restored.id, original.id);
      expect(restored.ticketNumber, original.ticketNumber);
      expect(restored.title, original.title);
      expect(restored.description, original.description);
      expect(restored.category, original.category);
      expect(restored.priority, original.priority);
      expect(restored.status, original.status);
      expect(restored.userId, original.userId);
      expect(restored.userName, original.userName);
      expect(restored.companyId, original.companyId);
      expect(restored.createdAt, original.createdAt);
      expect(restored.updatedAt, original.updatedAt);
      expect(restored.resolvedAt, isNull);
    });
  });
}
