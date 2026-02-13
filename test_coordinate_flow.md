# Coordinate Flow Analysis

## Step 1: Backend Returns (VERIFIED ✅)
```json
{
  "lat": 13.0827,  // Chennai, India
  "lon": 80.2707   // Chennai, India  
}
```

## Step 2: Mobile App Should Parse
```dart
Pin.fromJson({
  'lat': 13.0827,  // Should be assigned to pin.lat
  'lon': 80.2707   // Should be assigned to pin.lon
})
```

## Step 3: Distance Calculation
```dart
Geolocator.distanceBetween(
  userLat, userLon,  // User's GPS position
  pin.lat, pin.lon   // Pin position (13.0827, 80.2707)
)
```

## HYPOTHESIS:
If distance = 13,842km, then either:
- User GPS position is SWAPPED (user.lat = 80.something, user.lon = 13.something)
- OR Pin coordinates are SWAPPED when parsed

## NEXT: Check discovery API response parsing
