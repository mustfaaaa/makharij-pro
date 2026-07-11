import '../../dummy/dummy_user.dart';
import '../../services/service_locator.dart';

/// Email of the signed-in account (whatever the person entered at login /
/// signup), falling back to the prototype profile when no one is signed in.
String currentUserEmail() {
  final email = Services.auth.currentUser?.email;
  if (email != null && email.trim().isNotEmpty) return email.trim();
  return dummyUser.email;
}

/// The one consistent display name used across Home, Progress and Profile:
/// the part of the signed-in email before the '@'.
String currentUserName() {
  final email = currentUserEmail();
  final at = email.indexOf('@');
  return at > 0 ? email.substring(0, at) : email;
}

/// Single-letter avatar initial derived from the display name.
String currentUserInitial() {
  final name = currentUserName();
  return name.isNotEmpty ? name[0].toUpperCase() : 'M';
}
