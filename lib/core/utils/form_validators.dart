import '../constants/app_constants.dart';

class FormValidators {
  const FormValidators._();

  static String? required(String? value) =>
      value == null || value.trim().isEmpty ? 'Field ini wajib diisi.' : null;

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email wajib diisi.';
    final valid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim());
    return valid ? null : 'Format email tidak valid.';
  }

  static String? registrationEmail(String? value) {
    final emailError = email(value);
    if (emailError != null) return emailError;
    return isAllowedRegistrationEmail(value!)
        ? null
        : AppConstants.unsupportedRegistrationEmailMessage;
  }

  static bool isAllowedRegistrationEmail(String value) {
    final normalizedEmail = value.trim().toLowerCase();
    final atIndex = normalizedEmail.lastIndexOf('@');
    if (atIndex <= 0 || atIndex == normalizedEmail.length - 1) return false;
    final domain = normalizedEmail.substring(atIndex + 1);
    return AppConstants.allowedEmailDomains.contains(domain) ||
        AppConstants.allowedEmailDomainSuffixes
            .any((suffix) => domain.endsWith(suffix));
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Password wajib diisi.';
    return value.length < AppConstants.minimumPasswordLength
        ? 'Password minimal 8 karakter.'
        : null;
  }

  static String? confirmPassword(String? value, String password) =>
      value == password ? null : 'Konfirmasi password tidak cocok.';

  static String? ticketTitle(String? value) {
    final title = value?.trim() ?? '';
    if (title.isEmpty) return 'Judul kendala wajib diisi.';
    if (title.length > AppConstants.maxTicketTitleLength) {
      return 'Judul maksimal 100 karakter.';
    }
    return null;
  }

  static String? ticketDescription(String? value) {
    final description = value?.trim() ?? '';
    if (description.isEmpty) return 'Deskripsi wajib diisi.';
    if (description.length > AppConstants.maxTicketDescriptionLength) {
      return 'Deskripsi maksimal 1000 karakter.';
    }
    return null;
  }
}
