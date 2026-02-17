# 🔧 Multi-User Testing Guide

## 🚨 Critical Fixes Applied

### Backend Authentication Fixed
- **Removed all hardcoded user IDs** - All endpoints now require proper authentication
- **Improved PostGIS queries** - Using ST_DWithin for better 50m radius detection  
- **Added requireAuth middleware** - Every endpoint now validates JWT tokens

### Issues Fixed:
1. ✅ **"4 pins in diary" issue** - All users were sharing the same hardcoded user ID
2. ✅ **"Pins not visible within 50m"** - Improved PostGIS spatial queries
3. ✅ **Privacy concerns** - Strict user authentication now enforced

## 🧪 Multi-User Testing Steps

### Step 1: Create Test Users
```bash
cd backend
npx tsx scripts/create_test_users.ts
```

This creates two test accounts:
- **User 1**: user1@test.com / test123
- **User 2**: user2@test.com / test123

### Step 2: Start Backend Server
```bash
cd backend
npm run dev
```

### Step 3: Install & Run Mobile App
```bash
cd mobile 
flutter run --debug
```

### Step 4: Multi-User Test Flow

#### Test User Registration/Login:
1. **Register new users** or use the test credentials above
2. **Verify authentication** - app should require login
3. **Check user isolation** - each user sees only their own data

#### Test Pin Discovery:
1. **Login as User 1** - Create a pin at your current location
2. **Login as User 2** on same device or different device
3. **Walk within 50m** of User 1's pin location  
4. **Verify discovery** - User 2 should see User 1's pin on map

#### Test Diary Privacy:
1. **User 1 creates pins** and interacts with pins
2. **User 2 logs in** and checks diary
3. **Verify isolation** - User 2 should see 0 pins initially (not 4 random pins)
4. **User 2 creates own pins** - should see own activity only

## 🔍 What Should Work Now

### ✅ Proper Authentication
- No more shared hardcoded user ID
- Each user has isolated data
- JWT tokens required for all API calls

### ✅ Discovery System  
- 50m radius detection with PostGIS ST_DWithin
- Pins created by any user visible to others within range
- Real-time discovery via GPS heartbeat

### ✅ Diary Privacy
- Each user sees only their own pins and activities
- Timeline shows user-specific history
- Stats reflect individual user progress

### ✅ Multi-User Interactions
- Like/dislike pins created by other users
- Hide pins (personal mute) 
- Report inappropriate pins (community moderation)

## 🐛 Debugging Tips

If pins still don't appear:
1. **Check console logs** for PostGIS/coordinate errors
2. **Verify GPS coordinates** are being sent correctly
3. **Test with specific POST to /api/discovery/heartbeat**

If diary shows wrong data:
1. **Clear app data** and re-login
2. **Check JWT token** is valid
3. **Verify user ID** in API requests

If authentication fails:
1. **Check backend logs** for JWT errors  
2. **Verify user exists** in database
3. **Test login endpoint** directly

## 📱 Expected User Experience

### New User Flow:
1. **Register/Login** ➜ Personal empty diary
2. **Create first pin** ➜ Shows in "My Pins"  
3. **Walk near others' pins** ➜ Discovery notifications
4. **Interact with pins** ➜ Logged to personal diary

### Multi-User Scenario:
1. **User A creates pin** at coffee shop
2. **User B walks by** coffee shop (within 50m)
3. **User B discovers pin** via GPS heartbeat
4. **User B sees pin on map** and can interact
5. **Both users have separate** diary entries

## 🔒 Privacy Guarantees

- ✅ Users only see their own pins in "My Pins"
- ✅ Users only see their own diary timeline
- ✅ Users can discover others' pins within 50m radius
- ✅ Pin interactions (like/report) are user-specific
- ✅ No shared data between user sessions

The app now enforces proper multi-user separation while enabling location-based social discovery!