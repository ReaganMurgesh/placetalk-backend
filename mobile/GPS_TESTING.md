# Android Permissions Configuration

Add the following permissions to `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    
    <!-- Location Permissions -->
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
    
    <!-- For background location (if needed later) -->
    <!-- <uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" /> -->
    
    <!-- Internet Permission (should already exist) -->
    <uses-permission android:name="android.permission.INTERNET"/>

    <application
        ...
    </application>
</manifest>
```

# iOS Permissions Configuration

Add the following to `ios/Runner/Info.plist`:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>PlaceTalk needs your location to discover nearby pins and serendipitous moments</string>

<key>NSLocationAlwaysUsageDescription</key>
<string>PlaceTalk needs your location to notify you when you discover pins while exploring</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>PlaceTalk needs your location to discover pins around you</string>
```

# Testing GPS on Emulator/Simulator

## Android Emulator
1. Open emulator
2. Click the "..." button (More options)
3. Go to "Location"
4. Set custom coordinates
5. Click "Send"

**Test Coordinates (Amakusa, Japan):**
- Latitude: 32.4850
- Longitude: 130.1930

## iOS Simulator
1. Open simulator
2. Features → Location → Custom Location
3. Enter coordinates

**Test Coordinates (Tokyo):**
- Latitude: 35.6762
- Longitude: 139.6503

# Testing Discovery Flow

1. **Start Backend:**
   ```bash
   cd backend
   npm run dev
   ```

2. **Create Test Pin via API:**
   ```bash
   # Login and get token
   curl -X POST http://localhost:3000/auth/login \
     -H "Content-Type: application/json" \
     -d '{"email":"test@example.com","password":"password123"}'

   # Create pin near test location
   curl -X POST http://localhost:3000/api/pins \
     -H "Authorization: Bearer YOUR_TOKEN" \
     -H "Content-Type: application/json" \
     -d '{
       "title":"Test Pin",
       "directions":"Near the bridge",
       "lat":32.4850,
       "lon":130.1930,
       "type":"location",
       "pinCategory":"normal"
     }'
   ```

3. **Test in App:**
   - Login to app
   - Set emulator location to matching coordinates
   - Press "Discover" button
   - Should see "Discovered 1 pin(s)!" message

# Notes

- **Discovery Radius:** 50 meters (configured in backend)
- **Movement Threshold:** 20 meters (triggers new heartbeat)
- **Location Accuracy:** HIGH (best available)
- **Distance Filter:** 10 meters (for position stream)

# Troubleshooting

**"Location services not available":**
- Check if GPS is enabled in emulator/device
- Verify permissions are granted
- Check Android/iOS manifest files

**"Discovery failed":**
- Ensure backend is running
- Check API base URL in `api_config.dart`
- For Android emulator: use `http://10.0.2.2:3000`
- For iOS simulator: use `http://localhost:3000`
- For real device: use `http://YOUR_COMPUTER_IP:3000`

**No pins discovered:**
- Verify pin exists in backend (check database)
- Ensure GPS coordinates are within 50m of pin
- Check backend logs for discovery queries
