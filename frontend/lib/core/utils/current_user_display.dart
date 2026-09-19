import '../../dummy/dummy_user.dart';
import '../../models/user_profile.dart';
import '../../services/service_locator.dart';

/// Email of the signed-in account (whatever the person entered at login /
/// signup), falling back to the prototype profile when no one is signed in.
String currentUserEmail() {
  final email = Services.auth.currentUser?.email;
  if (email != null && email.trim().isNotEmpty) return email.trim();
  return dummyUser.email;
}

/// The part of the signed-in email before the '@': the fallback display name
/// when no profile name is known.
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

/// The first name to greet someone by: the name they gave (Firestore profile,
/// then Firebase Auth), else their email prefix.
///
/// `FirebaseUserService` merges missing fields over a prototype profile, so a
/// profile whose name is the prototype's while the account's email is not
/// means "no name was ever set", and must not greet a real user as someone
/// else.
String greetingName(UserProfile? profile) {
  final name = profile?.name.trim() ?? '';
  final isPlaceholder = name == dummyUser.name && currentUserEmail() != dummyUser.email;
  if (name.isNotEmpty && !isPlaceholder) return name.split(RegExp(r'\s+')).first;
  final authName = Services.auth.currentUser?.displayName?.trim() ?? '';
  if (authName.isNotEmpty) return authName.split(RegExp(r'\s+')).first;
  return currentUserName();
}
