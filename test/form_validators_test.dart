import 'package:flutter_test/flutter_test.dart';
import 'package:it_helpdesk_flutter/core/utils/form_validators.dart';
import 'package:it_helpdesk_flutter/models/ticket.dart';

void main() {
  group('FormValidators', () {
    test('requires values and validates email shape', () {
      expect(FormValidators.required(' '), isNotNull);
      expect(FormValidators.email(''), isNotNull);
      expect(FormValidators.email('not-an-email'), isNotNull);
      expect(FormValidators.email('ayu@example.com'), isNull);
    });

    test('requires passwords of at least eight characters', () {
      expect(FormValidators.password('short'), isNotNull);
      expect(FormValidators.password('long-enough'), isNull);
      expect(FormValidators.confirmPassword('different', 'password'), isNotNull);
      expect(FormValidators.confirmPassword('password', 'password'), isNull);
    });

    test('enforces title and description limits', () {
      expect(FormValidators.ticketTitle(' '), isNotNull);
      expect(FormValidators.ticketTitle('Printer error'), isNull);
      expect(FormValidators.ticketTitle('a' * 101), isNotNull);
      expect(FormValidators.ticketDescription('Issue detail'), isNull);
      expect(FormValidators.ticketDescription('a' * 1001), isNotNull);
    });
  });

  group('Ticket number', () {
    test('uses the first six document ID characters in uppercase', () {
      expect(ticketNumberForId('a1b2c3rest'), 'HD-A1B2C3');
    });

    test('handles document IDs shorter than six characters', () {
      expect(ticketNumberForId('abc'), 'HD-ABC');
    });
  });
}
