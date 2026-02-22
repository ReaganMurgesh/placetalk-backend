import type { FastifyInstance, FastifyReply, FastifyRequest } from 'fastify';
import { AuthService } from './auth.service.js';
import type { RegisterDTO, LoginDTO, UpdateProfileDTO } from './auth.types.js';

const authService = new AuthService();

export async function authRoutes(fastify: FastifyInstance) {
    // Register
    fastify.post<{ Body: RegisterDTO }>('/register', async (request, reply) => {
        try {
            const { name, email, password, role, homeRegion, country, nickname, bio, username } = request.body;

            // Validation
            if (!name || !email || !password) {
                return reply.code(400).send({ error: 'Name, email, and password are required' });
            }

            if (password.length < 8) {
                return reply.code(400).send({ error: 'Password must be at least 8 characters' });
            }

            const result = await authService.register({
                name,
                email,
                password,
                role: role || 'normal',
                homeRegion,
                country,
                nickname,
                bio,
                username,
            });

            return reply.code(201).send({
                message: 'User registered successfully',
                user: result.user,
                tokens: result.tokens,
            });
        } catch (error: any) {
            if (error.message === 'Email already registered') {
                return reply.code(409).send({ error: error.message });
            }
            if (error.statusCode && error.statusCode < 500) {
                return reply.code(error.statusCode).send({ error: error.message });
            }
            fastify.log.error(error);
            return reply.code(500).send({ error: 'Registration failed' });
        }
    });

    // Login
    fastify.post<{ Body: LoginDTO }>('/login', async (request, reply) => {
        try {
            const { email, password } = request.body;

            if (!email || !password) {
                return reply.code(400).send({ error: 'Email and password are required' });
            }

            const result = await authService.login({ email, password });

            return reply.send({
                message: 'Login successful',
                user: result.user,
                tokens: result.tokens,
            });
        } catch (error: any) {
            if (error.message === 'Invalid email or password') {
                return reply.code(401).send({ error: error.message });
            }
            fastify.log.error(error);
            return reply.code(500).send({ error: 'Login failed' });
        }
    });

    // Get current user (requires authentication)
    fastify.get('/me', {
        onRequest: [(fastify as any).authenticate],
    }, async (request: any, reply) => {
        try {
            const user = await authService.getUserById(request.user.userId);

            if (!user) {
                return reply.code(404).send({ error: 'User not found' });
            }

            return reply.send({ user });
        } catch (error) {
            fastify.log.error(error);
            return reply.code(500).send({ error: 'Failed to fetch user' });
        }
    });

    // Update profile (nickname, bio, username)
    fastify.patch<{ Body: UpdateProfileDTO }>('/profile', {
        onRequest: [(fastify as any).authenticate],
    }, async (request: any, reply) => {
        try {
            const updatedUser = await authService.updateProfile(request.user.userId, request.body);
            return reply.send({ user: updatedUser });
        } catch (error: any) {
            const status = error.statusCode ?? 500;
            if (status < 500) return reply.code(status).send({ error: error.message });
            fastify.log.error(error);
            return reply.code(500).send({ error: 'Failed to update profile' });
        }
    });
}
