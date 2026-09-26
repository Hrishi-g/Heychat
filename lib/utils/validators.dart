class Validators {
  /// Validates phone number: Must be exactly 10 numeric digits with no country code.
  static String? validatePhone(String? phone) {
    if (phone == null || phone.trim().isEmpty) {
      return 'Please enter your mobile number';
    }
    final cleanPhone = phone.trim();
    final phoneRegex = RegExp(r'^\d{10}$');
    if (!phoneRegex.hasMatch(cleanPhone)) {
      return 'Phone number must be exactly 10 digits (no country code)';
    }
    return null;
  }

  /// Validates email address format.
  static String? validateEmail(String? email) {
    if (email == null || email.trim().isEmpty) {
      return 'Please enter your email address';
    }
    final cleanEmail = email.trim();
    final emailRegex =
        RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(cleanEmail)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  /// Validates password criteria:
  /// - At least 8 characters in length
  /// - At least one uppercase letter (A-Z)
  /// - At least one number (0-9)
  /// - At least one special symbol (!@#$%^&* etc.)
  static String? validatePassword(String? password) {
    if (password == null || password.trim().isEmpty) {
      return 'Please enter a password';
    }
    final pass = password.trim();
    if (pass.length < 8) {
      return 'Password must be at least 8 characters long';
    }
    if (!RegExp(r'[A-Z]').hasMatch(pass)) {
      return 'Password must contain at least one uppercase letter (A-Z)';
    }
    if (!RegExp(r'[0-9]').hasMatch(pass)) {
      return 'Password must contain at least one number (0-9)';
    }
    if (!RegExp(r'[^a-zA-Z0-9]').hasMatch(pass)) {
      return r'Password must contain at least one special symbol (!@#$%^&* etc.)';
    }
    return null;
  }

  /// Formats ISO timestamp string or DateTime for chat display
  static String formatTimestamp(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '';
    try {
      final date = DateTime.parse(isoString).toLocal();
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0 && date.day == now.day) {
        final hour =
            date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
        final minute = date.minute.toString().padLeft(2, '0');
        final ampm = date.hour >= 12 ? 'PM' : 'AM';
        return '$hour:$minute $ampm';
      } else if (difference.inDays < 2 && now.day - date.day == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        return weekdays[date.weekday - 1];
      } else {
        return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year.toString().substring(2)}';
      }
    } catch (_) {
      return '';
    }
  }
}
