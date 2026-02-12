# PlaceTalk API Testing Guide

Complete guide to test all PlaceTalk backend endpoints with example requests.

---

## Prerequisites

1. **Start Docker containers:**
```bash
docker-compose up -d
```

2. **Start backend server:**
```bash
cd backend
npm run dev
```

Server should be running at: `http://localhost:3000`

---

## 1. Health Check

**No authentication required**

```bash
GET http://localhost:3000/health
```

**Expected Response:**
```json
{
  "status": "ok",
  "timestamp": "2026-02-11T12:30:00.000Z",
  "environment": "development"
}
```

---

## 2. User Registration

**Create a normal user:**

```bash
POST http://localhost:3000/auth/register
Content-Type: application/json

{
  "name": "Reagan Test",
  "email": "reagan@placetalk.com",
  "password": "securepass123",
  "role": "normal",
  "homeRegion": "Tokyo",
  "country": "Japan"
}
```

**Create a community user:**

```bash
POST http://localhost:3000/auth/register
Content-Type: application/json

{
  "name": "Kunpei Community",
  "email": "kunpei@placetalk.com",
  "password": "communitypass123",
  "role": "community",
  "homeRegion": "Amakusa",
  "country": "Japan"
}
```

**Expected Response:**
```json
{
  "message": "User registered successfully",
  "user": {
    "id": "uuid-here",
    "name": "Reagan Test",
    "email": "reagan@placetalk.com",
    "role": "normal",
    "homeRegion": "Tokyo",
    "country": "Japan",
    "createdAt": "2026-02-11T..."
  },
  "tokens": {
    "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
  }
}
```

**💾 Save the `accessToken` for subsequent requests!**

---

## 3. User Login

```bash
POST http://localhost:3000/auth/login
Content-Type: application/json

{
  "email": "reagan@placetalk.com",
  "password": "securepass123"
}
```

**Expected Response:**
```json
{
  "message": "Login successful",
  "user": { ... },
  "tokens": {
    "accessToken": "...",
    "refreshToken": "..."
  }
}
```

---

## 4. Get Current User

**Requires authentication**

```bash
GET http://localhost:3000/auth/me
Authorization: Bearer YOUR_ACCESS_TOKEN
```

**Expected Response:**
```json
{
  "user": {
    "id": "uuid",
    "name": "Reagan Test",
    "email": "reagan@placetalk.com",
    "role": "normal",
    "homeRegion": "Tokyo",
    "country": "Japan",
    "createdAt": "..."
  }
}
```

---

## 5. Create a Pin

**Requires authentication**

### Normal Pin (Location-based)

```bash
POST http://localhost:3000/api/pins
Authorization: Bearer YOUR_ACCESS_TOKEN
Content-Type: application/json

{
  "title": "Best ramen spot in Amakusa!",
  "directions": "Blue roof building beyond the shopping street, look for the red lantern",
  "details": "Try the tonkotsu ramen - it's incredible! Ask for extra chashu.",
  "lat": 32.4849,
  "lon": 130.1929,
  "type": "location",
  "pinCategory": "normal"
}
```

### Community Pin (Requires community role)

```bash
POST http://localhost:3000/api/pins
Authorization: Bearer COMMUNITY_USER_TOKEN
Content-Type: application/json

{
  "title": "Help harvest mandarins tomorrow!",
  "directions": "Bus stop in front of the mandarin grove",
  "details": "Looking for 5 volunteers. We'll provide lunch and 10 mandarins per person!",
  "lat": 32.5000,
  "lon": 130.2000,
  "type": "location",
  "pinCategory": "community",
  "visibleFrom": "08:00",
  "visibleTo": "18:00"
}
```

### Pin with Sensation Type

```bash
POST http://localhost:3000/api/pins
Authorization: Bearer YOUR_ACCESS_TOKEN
Content-Type: application/json

{
  "title": "Peaceful sunset viewing spot",
  "directions": "Through the alley, third bench on the left",
  "details": "From this angle you can see both the ocean and mountains at the same time",
  "lat": 32.4900,
  "lon": 130.1950,
  "type": "sensation",
  "pinCategory": "normal"
}
```

**Expected Response:**
```json
{
  "message": "Pin created successfully",
  "pin": {
    "id": "pin-uuid",
    "title": "Best ramen spot in Amakusa!",
    "directions": "Blue roof building beyond...",
    "details": "Try the tonkotsu ramen...",
    "lat": 32.4849,
    "lon": 130.1929,
    "type": "location",
    "pinCategory": "normal",
    "createdBy": "user-uuid",
    "expiresAt": "2026-02-14T...",  // 72 hours later
    "likeCount": 0,
    "dislikeCount": 0,
    "createdAt": "2026-02-11T..."
  }
}
```

---

## 6. Get Pin by ID

```bash
GET http://localhost:3000/api/pins/{PIN_ID}
Authorization: Bearer YOUR_ACCESS_TOKEN
```

**Expected Response:**
```json
{
  "pin": {
    "id": "pin-uuid",
    "title": "Best ramen spot in Amakusa!",
    "directions": "...",
    "lat": 32.4849,
    "lon": 130.1929,
    ...
  }
}
```

---

## 7. Get My Pins

```bash
GET http://localhost:3000/api/pins/my/pins
Authorization: Bearer YOUR_ACCESS_TOKEN
```

**Expected Response:**
```json
{
  "pins": [
    { "id": "...", "title": "...", ... },
    { "id": "...", "title": "...", ... }
  ],
  "count": 2
}
```

---

## 8. Discovery: GPS Heartbeat

**The core feature! Send your GPS location and discover nearby pins.**

### Discover pins near Amakusa, Japan

```bash
POST http://localhost:3000/api/discovery/heartbeat
Authorization: Bearer YOUR_ACCESS_TOKEN
Content-Type: application/json

{
  "lat": 32.4850,
  "lon": 130.1930
}
```

**If pins exist within 50m:**

```json
{
  "discovered": [
    {
      "id": "pin-uuid",
      "title": "Best ramen spot in Amakusa!",
      "directions": "Blue roof building beyond the shopping street...",
      "details": "Try the tonkotsu ramen...",
      "distance": 15,  // meters
      "type": "location",
      "pinCategory": "normal",
      "createdBy": "user-uuid"
    },
    {
      "id": "pin-uuid-2",
      "title": "Peaceful sunset viewing spot",
      "directions": "Through the alley, third bench on the left",
      "distance": 42,
      "type": "sensation",
      "pinCategory": "normal",
      "createdBy": "user-uuid"
    }
  ],
  "count": 2,
  "timestamp": "2026-02-11T..."
}
```

**If no pins nearby:**

```json
{
  "discovered": [],
  "count": 0,
  "timestamp": "2026-02-11T..."
}
```

### Test different locations:

**Tokyo Station:**
```json
{ "lat": 35.6812, "lon": 139.7671 }
```

**Matsuyama, Ehime:**
```json
{ "lat": 33.8416, "lon": 132.7656 }
```

**Chanakya University, Gujarat (India):**
```json
{ "lat": 23.3002, "lon": 72.6379 }
```

---

## 9. Discovery: Get Nearby Pins (Manual Check)

**Same as heartbeat but via GET request for testing:**

```bash
GET http://localhost:3000/api/discovery/nearby?lat=32.4850&lon=130.1930
Authorization: Bearer YOUR_ACCESS_TOKEN
```

---

## Complete Test Flow

### 1. Register a user
```bash
POST /auth/register
{
  "name": "Test User",
  "email": "test@example.com",
  "password": "password123",
  "role": "normal",
  "homeRegion": "Amakusa",
  "country": "Japan"
}
```

**Save the `accessToken`**

### 2. Create multiple pins
```bash
# Pin 1 - Ramen shop
POST /api/pins
Authorization: Bearer TOKEN
{
  "title": "Amazing ramen shop",
  "directions": "Near the red bridge",
  "lat": 32.4850,
  "lon": 130.1930,
  "type": "location",
  "pinCategory": "normal"
}

# Pin 2 - Scenic spot
POST /api/pins
Authorization: Bearer TOKEN
{
  "title": "Best sunset view",
  "directions": "Top of the hill",
  "lat": 32.4851,
  "lon": 130.1931,
  "type": "sensation",
  "pinCategory": "normal"
}

# Pin 3 - Too far away (won't be discovered)
POST /api/pins
Authorization: Bearer TOKEN
{
  "title": "Another restaurant",
  "directions": "Downtown area",
  "lat": 32.5000,
  "lon": 130.2000,
  "type": "location",
  "pinCategory": "normal"
}
```

### 3. Test discovery
```bash
# Near pins 1 and 2 (should discover both)
POST /api/discovery/heartbeat
Authorization: Bearer TOKEN
{
  "lat": 32.4850,
  "lon": 130.1930
}

# Far from all pins (should discover none)
POST /api/discovery/heartbeat
Authorization: Bearer TOKEN
{
  "lat": 35.6812,
  "lon": 139.7671
}
```

### 4. Check your pins
```bash
GET /api/pins/my/pins
Authorization: Bearer TOKEN
```

---

## Testing with curl

### Register
```bash
curl -X POST http://localhost:3000/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Test User",
    "email": "test@example.com",
    "password": "password123",
    "role": "normal"
  }'
```

### Login
```bash
curl -X POST http://localhost:3000/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "password123"
  }'
```

### Create Pin (replace TOKEN)
```bash
curl -X POST http://localhost:3000/api/pins \
  -H "Authorization: Bearer YOUR_TOKEN_HERE" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Test Pin",
    "directions": "Test directions",
    "lat": 32.4850,
    "lon": 130.1930,
    "type": "location",
    "pinCategory": "normal"
  }'
```

### Discovery Heartbeat
```bash
curl -X POST http://localhost:3000/api/discovery/heartbeat \
  -H "Authorization: Bearer YOUR_TOKEN_HERE" \
  -H "Content-Type: application/json" \
  -d '{
    "lat": 32.4850,
    "lon": 130.1930
  }'
```

---

## Error Responses

### 400 Bad Request
```json
{
  "error": "Invalid coordinates"
}
```

### 401 Unauthorized
```json
{
  "statusCode": 401,
  "error": "Unauthorized",
  "message": "No Authorization was found in request.headers"
}
```

### 403 Forbidden
```json
{
  "error": "Only community users can create community pins"
}
```

### 404 Not Found
```json
{
  "error": "Pin not found"
}
```

### 409 Conflict
```json
{
  "error": "Email already registered"
}
```

---

## Database Verification

### Check created pins
```bash
docker exec -it placetalk-postgres psql -U placetalk_user -d placetalk

SELECT id, title, ST_AsText(location), expires_at FROM pins;
```

### Check Redis geohash index
```bash
docker exec -it placetalk-redis redis-cli

KEYS geo:*
SMEMBERS geo:wvzyk5g  # Replace with actual geohash
```

### Check discoveries
```sql
SELECT * FROM discoveries ORDER BY discovered_at DESC LIMIT 10;
```

---

## Performance Testing

### Test geohash precision

**Precision 7 (~153m grid):**
- Amakusa: `wvzyk5g`
- Tokyo: `xn774c0`
- Matsuyama: `wv8fqxn`

### Measure discovery speed

Create 100 pins and test heartbeat response time:
```bash
time curl -X POST http://localhost:3000/api/discovery/heartbeat \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"lat": 32.4850, "lon": 130.1930}'
```

**Target: <100ms response time**

---

## Recommended Testing Tools

1. **Thunder Client** (VS Code extension)
2. **Postman**
3. **curl** (command line)
4. **http**pie** (modern curl alternative)

---

**Ready to test PlaceTalk's serendipity engine! 🎲**
