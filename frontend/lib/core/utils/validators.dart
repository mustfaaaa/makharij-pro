/// Lightweight form validators shared across the auth screens. Return null
/// when valid, or an error message to show under the field.
abstract class Validators {
  static final RegExp _emailRegex = RegExp(r'^[\w.\-+]+@[\w\-]+\.[\w\-.]+$');

  static String? email(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Email is required';
    if (!_emailRegex.hasMatch(v)) return 'Enter a valid email address';
    return null;
  }

  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Password is required';
    if (v.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  static String? name(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Name is required';
    if (v.length < 2) return 'Enter your full name';
    return null;
  }
}
