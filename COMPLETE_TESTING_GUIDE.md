# 🧪 Complete 2-User Testing Guide - PlaceTalk

## 🚀 Pre-Testing Setup

### 1. **Database Setup**
```bash
# Run the 2-user test setup script
cd backend
npx tsx scripts/setup_two_user_test.ts
```

### 2. **Start Backend Server** 
```bash
cd backend
npm run dev
```
*Verify server starts on https://placetalk-backend-1.onrender.com*

### 3. **Install APK**
```bash
# APK Location: mobile/build/app/outputs/flutter-apk/app-release.apk
adb install mobile/build/app/outputs/flutter-apk/app-release.apk
```

## 👥 Test User Accounts

**User 1**: `testuser1@placetalk.app` / `testpass123`
**User 2**: `testuser2@placetalk.app` / `testpass123`

## 🧪 Testing Scenarios

### **SCENARIO 1: User Isolation Verification**

#### **Test 1A: User 1 Login**
1. **Open PlaceTalk app**
2. **Login** with `testuser1@placetalk.app` / `testpass123`
3. **Navigate to Diary tab**
4. **Check "My Pins" section**
   - ✅ **EXPECTED**: Should show 2 pins ("Tokyo Station Pin", "Tokyo Tower Pin")
   - ❌ **FAILURE**: Shows 0 pins OR old test pins

#### **Test 1B: User 2 Login** 
1. **Logout User 1** (or use different device)
2. **Login** with `testuser2@placetalk.app` / `testpass123`
3. **Navigate to Diary tab**
4. **Check "My Pins" section**
   - ✅ **EXPECTED**: Should show 0 pins (empty diary)
   - ❌ **FAILURE**: Shows User 1's pins OR random pins

### **SCENARIO 2: Pin Creation Isolation**

#### **Test 2A: User 2 Creates Pin**
1. **Logged in as User 2**
2. **Navigate to Discover tab**
3. **Tap + button** to create pin
4. **Fill out pin details**:
   - Title: "User 2 Test Pin"
   - Directions: "Created by second user"
   - Details: "Testing isolation"
5. **Submit pin**
6. **Navigate to Diary → My Pins**
   - ✅ **EXPECTED**: Shows 1 pin (the one just created)

#### **Test 2B: Verify User 1 Doesn't See User 2's Pin in My Pins**
1. **Login as User 1** (different device or logout/login)
2. **Navigate to Diary → My Pins**
   - ✅ **EXPECTED**: Still shows only 2 original pins (not User 2's pin)

### **SCENARIO 3: Discovery System (50m Radius)**

#### **Test 3A: Location-Based Discovery**
1. **User 2 logged in**
2. **Navigate to Discover tab (Map)**
3. **Simulate location** near Tokyo Station:
   - Latitude: `35.6762`
   - Longitude: `139.6503`
4. **Check map**
   - ✅ **EXPECTED**: Should see User 1's "Tokyo Station Pin" on map
   - ❌ **FAILURE**: No pins show OR pins show outside 50m radius

#### **Test 3B: GPS Heartbeat Discovery**
1. **User 2 still at Tokyo Station location**
2. **Wait 10-15 seconds** for GPS heartbeat
3. **Check for discovery notifications**
   - ✅ **EXPECTED**: Should get discovery notification for User 1's pin

### **SCENARIO 4: Multi-User Interactions**

#### **Test 4A: Like/Report Other User's Pin**
1. **User 2 discovers User 1's pin** on map
2. **Tap on pin** for details
3. **Tap Like button**
4. **Check interaction works**
   - ✅ **EXPECTED**: Like count increases, User 2 can interact
   
#### **Test 4B: Verify Interaction Isolation**
1. **Login as User 1**
2. **Check same pin** User 2 just liked
   - ✅ **EXPECTED**: Like count reflects User 2's like
   - 🔒 **PRIVACY**: User 1 can't see WHO liked it (user privacy)

### **SCENARIO 5: Diary Privacy Verification**

#### **Test 5A: User Activity Logging**
1. **User 2 creates pin, likes User 1's pin, discovers pins**
2. **Navigate to Diary → Timeline**
   - ✅ **EXPECTED**: Shows ONLY User 2's activities
   - ❌ **FAILURE**: Shows User 1's activities or mixed data

#### **Test 5B: Cross-User Diary Check**
1. **Login as User 1**
2. **Navigate to Diary → Timeline**
   - ✅ **EXPECTED**: Shows ONLY User 1's historical activities
   - 🔒 **PRIVACY**: No trace of User 2's activities

## 🐛 Troubleshooting

### **App Won't Connect**
- Check backend is running on correct URL
- Verify WiFi/mobile data connection
- Check API_CONFIG.dart has correct baseUrl

### **Users Can See Each Other's "My Pins"**
- Database cleanup failed - run `setup_two_user_test.ts` again
- Check for hardcoded user IDs in backend logs
- Verify JWT authentication is working

### **Discovery Not Working**
- Location permissions enabled?
- GPS/Location services on?
- Test with manual coordinates first
- Check 50m radius calculation

### **Authentication Issues**
- Clear app data and re-login
- Check JWT token validity 
- Verify user exists in database

## ✅ Success Criteria

### **Multi-User Isolation**
- ✅ Each user sees only their own pins in "My Pins"
- ✅ Each user sees only their own diary timeline
- ✅ New users start with completely empty diary

### **Discovery System**
- ✅ Pins from other users appear on map within 50m
- ✅ GPS heartbeat triggers discovery notifications
- ✅ Discovery respects distance limits

### **Privacy & Security**
- ✅ No cross-user data leakage in diary
- ✅ Authentication required for all operations
- ✅ Users can interact with others' pins but can't see personal data

## 📊 Test Results Template

```
SCENARIO 1 - User Isolation: ✅/❌
- User 1 My Pins: ✅/❌ (Expected: 2, Actual: ___)
- User 2 My Pins: ✅/❌ (Expected: 0, Actual: ___)

SCENARIO 2 - Pin Creation: ✅/❌  
- User 2 creates pin: ✅/❌
- User 1 isolation: ✅/❌

SCENARIO 3 - Discovery: ✅/❌
- Map shows pins: ✅/❌
- 50m radius: ✅/❌

SCENARIO 4 - Interactions: ✅/❌
- Like/Report works: ✅/❌
- Privacy maintained: ✅/❌

SCENARIO 5 - Diary Privacy: ✅/❌
- Activity isolation: ✅/❌
- Cross-user privacy: ✅/❌
```

## 🎯 Final Validation

The multi-user system is working correctly when:
1. **Complete data isolation** between users
2. **Functional discovery** within 50m radius
3. **No shared personal data** (diary, my pins)
4. **Working social interactions** (like/report others' pins)

Your PlaceTalk app is ready for real-world multi-user testing! 🚀