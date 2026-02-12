# Building & Installing PlaceTalk APK on Your Android Phone

**Date:** February 11, 2026

---

## 📱 Quick Steps

1. **Build the APK**
2. **Transfer to Phone**
3. **Install & Test**

---

## Step 1: Build Release APK

### A. Open Terminal in Mobile Directory

```bash
cd C:\Users\reaga\Downloads\flutter_placetalk\mobile
```

### B. Build APK (Choose ONE method)

**Option 1: Build Release APK (Recommended for testing)**
```bash
flutter build apk --release
```

**Option 2: Build Debug APK (Faster build, larger file)**
```bash
flutter build apk --debug
```

**Option 3: Build Split APKs (Smaller file size)**
```bash
flutter build apk --split-per-abi --release
```

### C. Wait for Build to Complete

- Build time: 3-5 minutes (first time)
- Subsequent builds: 1-2 minutes

---

## Step 2: Locate the APK File

After build completes, find your APK at:

**Release APK:**
```
C:\Users\reaga\Downloads\flutter_placetalk\mobile\build\app\outputs\flutter-apk\app-release.apk
```

**Debug APK:**
```
C:\Users\reaga\Downloads\flutter_placetalk\mobile\build\app\outputs\flutter-apk\app-debug.apk
```

**Split APKs (if you chose option 3):**
```
app-armeabi-v7a-release.apk  (32-bit ARM)
app-arm64-v8a-release.apk    (64-bit ARM - RECOMMENDED)
app-x86_64-release.apk       (64-bit Intel)
```

**File Size:**
- Release APK: ~15-20 MB
- Debug APK: ~35-40 MB

---

## Step 3: Transfer APK to Your Phone

### Method 1: USB Cable (Fastest)

1. Connect phone to computer via USB
2. Enable "File Transfer" mode on phone
3. Copy APK file to phone's Download folder
4. Disconnect phone

### Method 2: Google Drive / Cloud Storage

1. Upload APK to Google Drive
2. Download on phone via Drive app

### Method 3: Direct ADB Install

```bash
# Enable USB Debugging on phone first
# Then run:
adb install build\app\outputs\flutter-apk\app-release.apk
```

---

## Step 4: Install on Phone

### A. Enable "Install Unknown Apps"

1. Go to **Settings** → **Security** (or **Apps**)
2. Find **Install unknown apps**
3. Select your **File Manager** or **Chrome**
4. Enable **Allow from this source**

### B. Install APK

1. Open **Files** app or **Downloads**
2. Tap the `app-release.apk` file
3. Tap **Install**
4. Wait for installation
5. Tap **Open**

---

## Step 5: Test on Your Phone

### A. Ensure Backend is Running

**On your computer:**
```bash
cd C:\Users\reaga\Downloads\flutter_placetalk\backend
npm run dev
```

Backend should be running at: `http://172.19.208.1:3000`

### B. Connect Phone to Same WiFi Network

**CRITICAL:** Your phone MUST be on the **same WiFi network** as your computer!

Check:
- Computer WiFi: Same network
- Phone WiFi: Same network
- Firewall: Allow port 3000

### C. Test API Connection

**On your phone, open browser and visit:**
```
http://172.19.208.1:3000/health
```

Should see: `{"status":"ok","timestamp":"..."}`

If it fails:
- Check Windows Firewall
- Ensure backend is running
- Verify phone is on same WiFi

### D. Launch PlaceTalk App

1. Open PlaceTalk app
2. **Register a new account**:
   - Name: Your name
   - Email: test@example.com
   - Password: password123
   - Role: Normal
   - Country: India (or Japan)
3. Login with credentials
4. Grant **Location Permission** when prompted
5. You should see the **Home Screen**!

---

## Step 6: Test Discovery

### A. Create a Test Pin

**On your computer, using curl:**

```bash
# First, login to get token
curl -X POST http://localhost:3000/auth/login \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"test@example.com\",\"password\":\"password123\"}"

# Copy the accessToken from response
# Then create a pin at your current location:

curl -X POST http://localhost:3000/api/pins \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN_HERE" \
  -H "Content-Type: application/json" \
  -d "{\"title\":\"Test Pin - I'm here!\",\"directions\":\"Look around you\",\"lat\":YOUR_LATITUDE,\"lon\":YOUR_LONGITUDE,\"type\":\"location\",\"pinCategory\":\"normal\"}"
```

**How to get your latitude/longitude:**
- Open Google Maps on your phone
- Long press your location
- Copy the coordinates shown

### B. Test Discovery

1. In PlaceTalk app, tap **"Discover"** FAB button
2. Grant location permission if asked
3. Wait for GPS to get your location
4. Should see: **"Discovered 1 pin(s)!"** 🎉

---

## 🐛 Troubleshooting

### "Can't install app"
- Enable "Install unknown apps" for your file manager
- Check if APK downloaded completely
- Try rebuilding: `flutter clean && flutter build apk --release`

### "Discovery failed: Failed host lookup"
- Backend not running on computer
- Phone not on same WiFi as computer
- Wrong IP address in `api_config.dart`
- Windows Firewall blocking port 3000

### "Location services not available"  
- Enable GPS on phone:  Settings → Location → On
- Grant location permission to PlaceTalk

### "No pins discovered"
- Pin not created in backend
- GPS coordinates don't match (must be within 50m)
- Check backend logs for discovery queries

### Backend not accessible from phone

**Fix Windows Firewall:**
```powershell
# Run PowerShell as Administrator
New-NetFirewallRule -DisplayName "PlaceTalk Backend" -Direction Inbound -LocalPort 3000 -Protocol TCP -Action Allow
```

### App crashes on launch
- Check if all dependencies installed: `flutter pub get`
- Rebuild: `flutter clean && flutter build apk --release`
- Check Android device logs: `adb logcat`

---

## 📝 Important Notes

### Network Requirements
- **Computer & Phone:** Same WiFi network
- **Backend:** Running on `http://172.19.208.1:3000`
- **Firewall:** Port 3000 must be open
- **Internet:** Both need internet for Google Fonts, etc.

### Testing Tips
1. **Start Backend First** (always!)
2. **Test in browser** before using app
3. **Create test pin** at your exact location
4. **Use real GPS coordinates** (not emulator simulation)
5. **Walk <50m** from pin to test discovery

### Discovery Testing
- Pin must be within **50 meters**
- GPS accuracy: **10-20 meters** (outdoors)
- Indoor GPS: **May not work well**
- Best results: **Outside, clear sky**

---

## 🎉 Success Checklist

- [ ] Backend running (`http://172.19.208.1:3000/health` works)
- [ ] APK built successfully
- [ ] APK installed on phone
- [ ] App launches without crashing
- [ ] Registration works
- [ ] Login works
- [ ] Home screen displays
- [ ] Location permission granted
- [ ] "Discover" button works
- [ ] Pin discovered successfully

---

## 🚀 Next Steps After Testing

1. **Test pin creation** (once UI is built)
2. **Test background discovery** (once implemented)
3. **Test in different locations** (walk around)
4. **Share APK** with teammates for testing
5. **Prepare for Japan field test**

---

**Ready to test PlaceTalk on your real device! 📱**

If you encounter any issues, check the troubleshooting section or the backend logs.
