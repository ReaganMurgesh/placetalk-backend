# PlaceTalk Flutter Mobile App - README

Flutter mobile application for PlaceTalk location-based discovery platform.

## Features

### ✅ Implemented
- User authentication (login/register)
- JWT token management
- Material 3 UI design
- Riverpod state management
- API client for all backend endpoints

### ⏳ In Progress
- Home screen with user info
- Map integration (MapLibre)
- GPS location tracking
- Discovery notifications

### 📋 Planned
- Pin creation
- Discovery history
- User profile
- Settings
- Community features

## Setup

### Prerequisites
- Flutter SDK 3.10+
- Android Studio / Xcode
- Backend API running at `http://localhost:3000`

### Installation

```bash
# Install dependencies
flutter pub get

# Run on device/emulator
flutter run
```

### Configuration

Update API baseUrl in `lib/core/config/api_config.dart`:

```dart
static const String baseUrl = 'http://localhost:3000';  // For iOS simulator
// static const String baseUrl = 'http://10.0.2.2:3000';  // For Android emulator
// static const String baseUrl = 'http://YOUR_IP:3000';    // For real device
```

## Project Structure

```
lib/
├── core/
│   └── config/
│       └── api_config.dart       # API configuration
├── models/
│   ├── user.dart                 # User data model
│   └── pin.dart                  # Pin data model
├── providers/
│   └── auth_provider.dart        # Authentication state
├── screens/
│   ├── auth/
│   │   ├── login_screen.dart     # Login UI
│   │   └── register_screen.dart  # Registration UI
│   └── home/
│       └── home_screen.dart      # Main home screen
├── services/
│   └── api_client.dart           # HTTP API client
└── main.dart                     # App entry point
```

## Dependencies

```yaml
flutter_riverpod: ^2.4.0      # State management
google_fonts: ^6.1.0          # Typography
dio: ^5.4.0                   # HTTP client
geolocator: ^10.1.0           # GPS tracking
permission_handler: ^11.0.1   # Permissions
shared_preferences: ^2.2.2    # Local storage
json_annotation: ^4.8.1       # JSON serialization
```

## Testing

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage

# Run on specific device
flutter run -d <device_id>
```

## Build

```bash
# Android APK
flutter build apk --release

# iOS IPA
flutter build ios --release

# Check for issues
flutter doctor
```

## Features Demo

### Login/Register
- Email validation
- Password strength check
- Role selection (Normal/Community)
- Country selection
- Error handling

### Home Screen
- User profile display
- Map placeholder (MapLibre coming soon)
- Quick actions (Create Pin, My Pins)
- Discovery button (GPS coming soon)

## Next Steps

1. **GPS Integration**
   - Implement location service
   - Request permissions
   - Background tracking

2. **Map View**
   - Add MapLibre GL
   - Display user location
   - Show discovered pins

3. **Pin Creation**
   - Create pin form
   - Direction input
   - Type/category selection

4. **Discovery**
   - Heartbeat scheduler
   - Push notifications
   - Discovery history

## Contributing

See main project README for contribution guidelines.

## License

Proprietary - PlaceTalk Development Team
