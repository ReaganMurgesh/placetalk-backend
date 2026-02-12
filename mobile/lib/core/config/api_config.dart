/// API Configuration
class ApiConfig {
  // Your WiFi IP — phone and computer must be on the same WiFi
  // Find your IP: Windows → ipconfig → "Wireless LAN adapter Wi-Fi" → IPv4
  static const String baseUrl = 'https://nia-haplitic-compactly.ngrok-free.dev'; // Ngrok URL
  
  // For Android Emulator use: http://10.0.2.2:3000
  // For iOS Simulator use: http://localhost:3000
  // For Real Device use: http://YOUR_WIFI_IP:3000
  
  // Auth
  static const String authRegister = '/auth/register';
  static const String authLogin = '/auth/login';
  static const String authMe = '/auth/me';
  
  // Discovery
  static const String discoveryHeartbeat = '/discovery/heartbeat';
  static const String discoveryNearby = '/discovery/nearby';
  
  // Pins
  static const String pinsCreate = '/pins';
  static const String pinsGetById = '/pins';  // + /{id}
  static const String pinsMyPins = '/pins/my/pins';
  
  // Discovery settings
  static const double discoveryRadiusMeters = 50.0;
  static const double movementThresholdMeters = 20.0;
}
