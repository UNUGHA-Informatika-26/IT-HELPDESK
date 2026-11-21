import 'package:flutter_test/flutter_test.dart';
import 'package:it_helpdesk_flutter/core/constants/app_constants.dart';
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

    test('allows supported registration email domains only', () {
      expect(FormValidators.registrationEmail('person@gmail.com'), isNull);
      expect(FormValidators.registrationEmail(' person@Yahoo.com '), isNull);
      expect(FormValidators.registrationEmail('staff@kampus.ac.id'), isNull);

      for (final domain in [
        'mailinator.com',
        '10minutemail.com',
        'tempmail.com',
      ]) {
        expect(
          FormValidators.registrationEmail('person@$domain'),
          AppConstants.unsupportedRegistrationEmailMessage,
        );
      }
    });

    test('requires passwords of at least eight characters', () {
      expect(FormValidators.password('short'), isNotNull);
      expect(FormValidators.password('long-enough'), isNull);
      expect(
          FormValidators.confirmPassword('different', 'password'), isNotNull);
      expect(FormValidators.confirmPassword('password', 'password'), isNull);
    });

    test('enforces title and description limits', () {
      expect(FormValidators.ticketTitle(' '), isNotNull);
      expect(FormValidators.ticketTitle('Printer error'), isNull);
      expect(FormValidators.ticketTitle('a' * 101), isNotNull);
      expect(FormValidators.ticketDescription('Issue detail'), isNull);
      expect(FormValidators.ticketDescription('a' * 1001), isNotNull);
    });

    test('validates required custom category descriptions up to 50 chars', () {
      expect(FormValidators.customCategory(' '), isNotNull);
      expect(FormValidators.customCategory('a' * 50), isNull);
      expect(FormValidators.customCategory('a' * 51), isNotNull);
    });

    test('composes and splits custom category title prefixes', () {
      const item = 'Proyektor';
      const title = 'Tidak menyala';
      final composed = CustomCategoryTitle.compose(item, title);

      expect(composed, '[Proyektor] Tidak menyala');
      expect(CustomCategoryTitle.split(composed), (item, title));
      expect(CustomCategoryTitle.split('Judul lama'), (null, 'Judul lama'));
    });

    test('enforces 100 characters for combined custom category titles', () {
      final fits = CustomCategoryTitle.compose('a' * 10, 'b' * 87);
      final exceeds = CustomCategoryTitle.compose('a' * 10, 'b' * 88);

      expect(FormValidators.ticketTitle(fits), isNull);
      expect(FormValidators.ticketTitle(exceeds), isNotNull);
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
