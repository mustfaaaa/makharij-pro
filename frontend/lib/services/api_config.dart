/// Backend base URL. Not auto-detected because "localhost" means something
/// different depending on where the app is actually running:
///   - Android emulator: the host machine is reachable at 10.0.2.2, not localhost.
///   - Physical Android/iOS device: needs the dev machine's real LAN IP
///     (same Wi-Fi network), e.g. http://192.168.1.23:8000.
///   - Windows/web/desktop running on the same machine as the backend: localhost works.
/// Change this to match how you're actually running the app during development.
/// Currently set to plain localhost, which covers three of those cases at once:
/// Windows desktop/web on this machine, and a physical device reached through
/// `adb reverse tcp:8000 tcp:8000` -- that tunnel maps the phone's own
/// localhost:8000 back to this machine, so no LAN IP and no firewall rule are
/// involved. Re-run the adb reverse after replugging the phone; it does not
/// survive a disconnect. Switch to 10.0.2.2 only for the Android emulator.
const String kApiBaseUrl = 'http://127.0.0.1:8000';
