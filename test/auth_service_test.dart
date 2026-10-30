import 'package:flutter_test/flutter_test.dart';
import 'package:it_helpdesk_flutter/core/constants/app_constants.dart'
    show AppConstants, UserRoles;
import 'package:it_helpdesk_flutter/services/auth_service.dart';

void main() {
  group('Email verification policy', () {
    test('does not require verification before the cutoff', () {
      expect(
        requiresEmailVerification(
          AppConstants.emailVerificationEnforcedFrom
              .subtract(const Duration(microseconds: 1)),
        ),
        isFalse,
      );
    });

    test('requires verification after the cutoff', () {
      expect(
        requiresEmailVerification(
          AppConstants.emailVerificationEnforcedFrom
              .add(const Duration(microseconds: 1)),
        ),
        isTrue,
      );
    });

    test('does not require verification when creation time is unknown', () {
      expect(requiresEmailVerification(null), isFalse);
    });

    test('does not require verification for admins created after cutoff', () {
      expect(
        mustVerifyEmail(
          role: UserRoles.admin,
          creationTime: AppConstants.emailVerificationEnforcedFrom
              .add(const Duration(days: 1)),
        ),
        isFalse,
      );
    });
  });
}
