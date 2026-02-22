import { Server } from 'socket.io';
import type { Server as HttpServer } from 'http';

let _io: Server | null = null;

/**
 * Initialize Socket.io and attach to the existing Fastify HTTP server.
 * Call once after fastify.listen() resolves.
 */
export function initSocketIO(httpServer: HttpServer): Server {
    _io = new Server(httpServer, {
        cors: {
            origin: '*',
            methods: ['GET', 'POST'],
        },
        path: '/socket.io',
        // Allow both websocket and long-polling (Render free tier compatible)
        transports: ['websocket', 'polling'],
    });

    _io.on('connection', (socket) => {
        console.log(`🔌 Socket client connected: ${socket.id}`);

        // Client joins a community room to receive its messages
        socket.on('join_community', (communityId: string) => {
            socket.join(`community_${communityId}`);
            console.log(`👥 ${socket.id} joined community_${communityId}`);
        });

        // Client leaves a community room
        socket.on('leave_community', (communityId: string) => {
            socket.leave(`community_${communityId}`);
        });

        // 1.4: Join a personal user room for creator footprint alerts
        socket.on('join_user_room', (userId: string) => {
            socket.join(`user_${userId}`);
            console.log(`👤 ${socket.id} joined user_${userId} (creator alerts)`);
        });

        socket.on('disconnect', () => {
            console.log(`🔌 Socket disconnected: ${socket.id}`);
        });
    });

    console.log('✅ Socket.io server initialized');
    return _io;
}

/** Get the active Socket.io instance (null before initSocketIO is called) */
export function getIO(): Server | null {
    return _io;
}

/**
 * Broadcast an event to every socket in a named room.
 * Safe to call before init — simply no-ops if io is null.
 */
export function emitToRoom(room: string, event: string, data: unknown): void {
    _io?.to(room).emit(event, data);
}
