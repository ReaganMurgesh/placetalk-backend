# PlaceTalk Backend API

Backend server for PlaceTalk location-based discovery platform.

## Quick Start

### 1. Start Databases (Docker)
```bash
# From project root
docker-compose up -d
```

### 2. Run Migrations
```bash
npm run db:migrate
```

### 3. Start Development Server
```bash
npm run dev
```

Server will start at `http://localhost:3000`

## Project Structure

```
backend/
├── src/
│   ├── config/         # Database & Redis connections
│   ├── modules/        # Feature modules
│   │   ├── auth/       # Authentication
│   │   ├── pins/       # Pin management
│   │   ├── discovery/  # GPS discovery engine
│   │   └── users/      # User management
│   ├── utils/          # Utilities (geohash, etc.)
│   ├── workers/        # Background jobs
│   └── server.ts       # Main entry point
├── migrations/         # SQL migrations
└── .env                # Environment variables
```

## Environment Variables

See `.env` file for configuration. Key variables:

- `DATABASE_*`: PostgreSQL connection
- `REDIS_*`: Redis connection
- `JWT_SECRET`: Authentication secret
- `DISCOVERY_RADIUS_METERS`: Pin discovery radius (default: 50m)

## API Endpoints

### Health Check
- `GET /health` - Server status

### Authentication (Coming Soon)
- `POST /auth/register` - User registration
- `POST /auth/login` - User login
- `GET /auth/me` - Current user

### Discovery (Coming Soon)
- `POST /api/discovery/heartbeat` - GPS ping
- `GET /api/pins/nearby` - Get nearby pins

## Database Schema

7 Tables:
- `users` - User accounts with role-based access
- `pins` - Location pins with PostGIS geospatial data
- `attributes` - Pin categories/communities
- `attribute_memberships` - User-attribute relationships
- `interactions` - Likes, dislikes, comments
- `discoveries` - Discovery analytics
- `diary_entries` - User reflections

## Tech Stack

- **Framework**: Fastify
- **Language**: TypeScript
- **Database**: PostgreSQL 15 + PostGIS
- **Cache**: Redis 7
- **Queue**: BullMQ
- **Auth**: JWT

## Development

```bash
# Install dependencies
npm install

# Run in dev mode (hot reload)
npm run dev

# Build for production
npm run build

# Start production server
npm start
```

---

**Team**: Kunpei-san (Lead), Reagan, Sanay
