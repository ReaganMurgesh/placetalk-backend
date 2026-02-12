# PlaceTalk Quick Start Guide

## Start Development Environment

### 1. Start Databases
```bash
cd C:\Users\reaga\Downloads\flutter_placetalk
docker-compose up -d
```

### 2. Start Backend Server
```bash
cd backend
npm run dev
```

Server runs at: http://localhost:3000

### 3. Test API

**Health Check:**
```bash
curl http://localhost:3000/health
```

**Register User:**
```json
POST http://localhost:3000/auth/register
Content-Type: application/json

{
  "name": "Kunpei",
  "email": "kunpei@placetalk.com",
  "password": "securepass123",
  "role": "community",
  "homeRegion": "Amakusa",
  "country": "Japan"
}
```

**Login:**
```json
POST http://localhost:3000/auth/login
Content-Type: application/json

{
  "email": "kunpei@placetalk.com",
  "password": "securepass123"
}
```

## Useful Commands

### Docker
```bash
# Check running containers
docker ps

# View logs
docker logs placetalk-postgres
docker logs placetalk-redis

# Stop all
docker-compose down

# Restart
docker-compose restart
```

### Database
```bash
# Connect to PostgreSQL
docker exec -it placetalk-postgres psql -U placetalk_user -d placetalk

# Inside psql:
\dt              # List tables
\d pins          # Describe pins table
\q               # Quit
```

### Backend
```bash
cd backend

npm run dev      # Development mode (hot reload)
npm run build    # Compile TypeScript
npm start        # Production mode
```

### Flutter
```bash
cd mobile

flutter pub get  # Install dependencies
flutter run      # Run on connected device/emulator
flutter doctor   # Check setup
```

##Project Structure

```
flutter_placetalk/
├── backend/          # API server
├── mobile/           # Flutter app
└── docker-compose.yml
```

## Next Tasks

1. **Implement Discovery Engine** (backend)
   - Geohash utility
   - Heartbeat endpoint
   - Redis geospatial indexing

2. **Flutter Setup** (mobile)
   - Add MapLibre dependency
   - Configure background location
   - Add Firebase for notifications

3. **Test & Iterate**
   - Create test pins
   - Verify GPS discovery
   - Tune distance threshold

---

**Team**: Kunpei-san, Reagan, Sanay  
**Target**: MVP ready mid-February for Japan field test
