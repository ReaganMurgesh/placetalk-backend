import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import { pool } from '../../config/database.js';
import type { RegisterDTO, LoginDTO, UserResponse, AuthTokens } from './auth.types.js';

const SALT_ROUNDS = 10;  // Reduced from 12 for faster hashing (still secure)
const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key';
const JWT_REFRESH_SECRET = process.env.JWT_REFRESH_SECRET || 'your-refresh-secret';

export class AuthService {
    // Register new user
    async register(data: RegisterDTO): Promise<{ user: UserResponse; tokens: AuthTokens }> {
        // Check if email already exists
        const existingUser = await pool.query(
            'SELECT id FROM users WHERE email = $1',
            [data.email]
        );

        if (existingUser.rows.length > 0) {
            throw new Error('Email already registered');
        }

        // Hash password
        const passwordHash = await bcrypt.hash(data.password, SALT_ROUNDS);

        // Insert user
        const result = await pool.query(
            `INSERT INTO users (name, email, password_hash, role, home_region, country)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING id, name, email, role, home_region, country, created_at`,
            [data.name, data.email, passwordHash, data.role || 'normal', data.homeRegion, data.country || 'Japan']
        );

        const user = result.rows[0];

        // Generate tokens with role
        const tokens = this.generateTokens(user.id, user.email, user.role);

        return {
            user: {
                id: user.id,
                name: user.name,
                email: user.email,
                role: user.role,
                homeRegion: user.home_region,
                country: user.country,
                createdAt: user.created_at,
            },
            tokens,
        };
    }

    // Login user
    async login(data: LoginDTO): Promise<{ user: UserResponse; tokens: AuthTokens }> {
        // Find user
        const result = await pool.query(
            'SELECT id, name, email, password_hash, role, home_region, country, created_at FROM users WHERE email = $1',
            [data.email]
        );

        if (result.rows.length === 0) {
            throw new Error('Invalid email or password');
        }

        const user = result.rows[0];

        // Verify password
        const passwordMatch = await bcrypt.compare(data.password, user.password_hash);

        if (!passwordMatch) {
            throw new Error('Invalid email or password');
        }

        // Update last login
        await pool.query('UPDATE users SET last_login = NOW() WHERE id = $1', [user.id]);

        // Generate tokens with role
        const tokens = this.generateTokens(user.id, user.email, user.role);

        return {
            user: {
                id: user.id,
                name: user.name,
                email: user.email,
                role: user.role,
                homeRegion: user.home_region,
                country: user.country,
                createdAt: user.created_at,
            },
            tokens,
        };
    }

    // Get user by ID
    async getUserById(userId: string): Promise<UserResponse | null> {
        const result = await pool.query(
            'SELECT id, name, email, role, home_region, country, created_at FROM users WHERE id = $1',
            [userId]
        );

        if (result.rows.length === 0) {
            return null;
        }

        const user = result.rows[0];
        return {
            id: user.id,
            name: user.name,
            email: user.email,
            role: user.role,
            homeRegion: user.home_region,
            country: user.country,
            createdAt: user.created_at,
        };
    }

    // Generate JWT tokens with role
    private generateTokens(userId: string, email: string, role: string): AuthTokens {
        const accessToken = jwt.sign(
            { userId, email, role },  // Include role in JWT payload
            JWT_SECRET,
            { expiresIn: (process.env.JWT_EXPIRES_IN || '7d') as string }
        );

        const refreshToken = jwt.sign(
            { userId, email, role },  // Include role in refresh token
            JWT_REFRESH_SECRET,
            { expiresIn: (process.env.JWT_REFRESH_EXPIRES_IN || '30d') as string }
        );

        return { accessToken, refreshToken };
    }

    // Verify access token
    verifyAccessToken(token: string): { userId: string; email: string; role: string } {
        try {
            const decoded = jwt.verify(token, JWT_SECRET) as { userId: string; email: string; role: string };
            return decoded;
        } catch (error) {
            throw new Error('Invalid or expired token');
        }
    }
}
