/// Backend base URL. Not auto-detected because "localhost" means something
/// different depending on where the app is actually running:
///   - Android emulator: the host machine is reachable at 10.0.2.2, not localhost.
///   - Physical Android/iOS device: needs the dev machine's real LAN IP
///     (same Wi-Fi network), e.g. http://192.168.1.23:8000.
///   - Windows/web/desktop running on the same machine as the backend: localhost works.
/// Change this to match how you're actually running the app during development.
/// Currently set for Windows desktop (same machine as the backend) -- switch to
/// 10.0.2.2 for the Android emulator, or your machine's LAN IP for a physical device.
const String kApiBaseUrl = 'http://127.0.0.1:8000';
