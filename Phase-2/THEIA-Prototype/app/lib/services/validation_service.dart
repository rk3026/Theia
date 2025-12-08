class ValidationService {
  ValidationService._();

  static final RegExp _phoneRegex = RegExp(r'^[+0-9 ()-]{7,}$');
  static final RegExp _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? validateRequired(String? value, {String fieldName = 'Field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  static String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }
    final digitsOnly = value.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digitsOnly.length < 7 || !_phoneRegex.hasMatch(value)) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    if (!_emailRegex.hasMatch(value.trim())) {
      return 'Enter a valid email address';
    }
    return null;
  }

  static String? validateRoom(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    if (value.length > 32) {
      return 'Room description is too long';
    }
    return null;
  }
}
