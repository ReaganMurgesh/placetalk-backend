# PlaceTalk - Quick Deploy to Phone 📱

**Your Computer IP:** `172.19.208.1`

---

## ⚡ Quick Steps

### 1. Build APK (NOW - 3-5 minutes)
```bash
cd C:\Users\reaga\Downloads\flutter_placetalk\mobile
flutter build apk --release
```

### 2. Find APK
```
C:\Users\reaga\Downloads\flutter_placetalk\mobile\build\app\outputs\flutter-apk\app-release.apk
```

### 3. Transfer to Phone
- USB cable → Copy to phone's Downloads
- OR Google Drive → Download on phone

### 4. Install on Phone
- Settings → Install unknown apps → Enable for Files
- Open Downloads → Tap `app-release.apk` → Install

---

## ✅ Before Testing

### A. Start Backend (Computer)
```bash
cd C:\Users\reaga\Downloads\flutter_placetalk\backend
npm run dev
```

### B. Allow Firewall (Run PowerShell as Admin)
```powershell
New-NetFirewallRule -DisplayName "PlaceTalk" -Direction Inbound -LocalPort 3000 -Protocol TCP -Action Allow
```

### C. Connect Phone to Same WiFi
- Phone & Computer: **SAME WIFI NETWORK**

### D. Test Connection
**On phone browser, visit:**
```
http://172.19.208.1:3000/health
```
Should see: `{"status":"ok",...}`

---

## 🧪 Testing Flow

1. **Open PlaceTalk** on phone
2. **Register:**
   - Email: `test@example.com`
   - Password: `password123`
   - Role: Normal
3. **Grant GPS permission**
4. **Press "Discover"** button
5. Should see your GPS coordinates!

---

## 📍 Create Test Pin

**On computer:**
```bash
# Login
curl -X POST http://localhost:3000/auth/login \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"test@example.com\",\"password\":\"password123\"}"

# Copy the access token, then:
curl -X POST http://localhost:3000/api/pins \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"title\":\"I am here!\",\"directions\":\"Right next to you\",\"lat\":YOUR_LAT,\"lon\":YOUR_LON,\"type\":\"location\",\"pinCategory\":\"normal\"}"
```

**Get your lat/lon:** Long press on Google Maps at your location

---

## 🐛 Common Issues

**"Discovery failed"**
→ Backend not running or wrong IP

**"Location not available"**
→ Enable GPS: Settings → Location → On

**"No pins discovered"**
→ Create pin at your exact GPS location (<50m)

**Backend not reachable**
→ Check firewall, WiFi, and backend running

---

## 📞 Need Help?

See full guide: `mobile/APK_BUILD_INSTALL.md`

**APK Location:**
```
build/app/outputs/flutter-apk/app-release.apk
```

---

**Ready to test PlaceTalk! 🎉**
