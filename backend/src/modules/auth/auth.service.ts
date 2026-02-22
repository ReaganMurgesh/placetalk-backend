import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import { pool } from '../../config/database.js';
import type { RegisterDTO, LoginDTO, UserResponse, AuthTokens, UpdateProfileDTO } from './auth.types.js';

// ── Text validation helpers ─────────────────────────────────────────────────
const ALPHANUMERIC_RE = /^[a-zA-Z0-9_]+$/;
function validateProfileFields(data: { nickname?: string; bio?: string; username?: string }): string | null {
    if (data.nickname !== undefined && data.nickname.length > 20) return 'Nickname must be 20 characters or fewer';
    if (data.bio !== undefined && data.bio.length > 15) return 'Bio must be 15 characters or fewer';
    if (data.username !== undefined) {
        if (data.username.length > 15) return 'Username must be 15 characters or fewer';
        if (!ALPHANUMERIC_RE.test(data.username)) return 'Username may only contain letters, digits, and underscores';
    }
    return null;
}

const SALT_ROUNDS = 10;  // Reduced from 12 for faster hashing (still secure)
const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key';
const JWT_REFRESH_SECRET = process.env.JWT_REFRESH_SECRET || 'your-refresh-secret';

export class AuthService {
    // Register new user
    async register(data: RegisterDTO): Promise<{ user: UserResponse; tokens: AuthTokens }> {
        const email = data.email.trim().toLowerCase();

        // Check if email already exists
        const existingUser = await pool.query(
            'SELECT id FROM users WHERE email = $1',
            [email]
        );

        if (existingUser.rows.length > 0) {
            throw new Error('Email already registered');
        }

        // Validate optional profile fields
        const profileErr = validateProfileFields(data);
        if (profileErr) throw Object.assign(new Error(profileErr), { statusCode: 400 });

        // Hash password
        const passwordHash = await bcrypt.hash(data.password, SALT_ROUNDS);

        // Insert user
        const result = await pool.query(
            `INSERT INTO users (name, email, password_hash, role, home_region, country, nickname, bio, username)
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
             RETURNING id, name, email, COALESCE(role, 'normal') as role, home_region, country, created_at,
                       nickname, bio, username, COALESCE(is_b2b_partner, FALSE) as is_b2b_partner`,
            [
                data.name, email, passwordHash, data.role || 'normal',
                data.homeRegion, data.country || 'Japan',
                data.nickname ?? null, data.bio ?? null, data.username ?? null,
            ]
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
                nickname: user.nickname ?? undefined,
                bio: user.bio ?? undefined,
                username: user.username ?? undefined,
                isB2bPartner: user.is_b2b_partner ?? false,
            },
            tokens,
        };
    }

    // Login user
    async login(data: LoginDTO): Promise<{ user: UserResponse; tokens: AuthTokens }> {
        const email = data.email.trim().toLowerCase();

        // Find user - use COALESCE to handle NULL role
        const result = await pool.query(
            `SELECT id, name, email, password_hash,
                    COALESCE(role, 'normal') as role,
                    home_region, country, created_at, nickname, bio, username,
                    COALESCE(is_b2b_partner, FALSE) as is_b2b_partner
             FROM users WHERE email = $1`,
            [email]
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

        // Generate tokens with role (removed last_login update - column doesn't exist)
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
                nickname: user.nickname ?? undefined,
                bio: user.bio ?? undefined,
                username: user.username ?? undefined,
                isB2bPartner: user.is_b2b_partner ?? false,
            },
            tokens,
        };
    }

    // Get user by ID
    async getUserById(userId: string): Promise<UserResponse | null> {
        const result = await pool.query(
            `SELECT id, name, email, role, home_region, country, created_at,
                    nickname, bio, username,
                    COALESCE(is_b2b_partner, FALSE) as is_b2b_partner
             FROM users WHERE id = $1`,
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
            nickname: user.nickname ?? undefined,
            bio: user.bio ?? undefined,
            username: user.username ?? undefined,
            isB2bPartner: user.is_b2b_partner ?? false,
        };
    }

    // Update profile fields (nickname, bio, username)
    async updateProfile(userId: string, data: UpdateProfileDTO): Promise<UserResponse> {
        // Validate
        const err = validateProfileFields(data);
        if (err) throw Object.assign(new Error(err), { statusCode: 400 });

        // Build dynamic SET clause for only provided fields
        const fields: string[] = [];
        const values: (string | null)[] = [];
        let idx = 1;

        if (data.nickname !== undefined) { fields.push(`nickname = $${idx++}`); values.push(data.nickname); }
        if (data.bio !== undefined)      { fields.push(`bio = $${idx++}`); values.push(data.bio); }
        if (data.username !== undefined) {
            // Check uniqueness before hitting DB constraint
            const clash = await pool.query(
                'SELECT id FROM users WHERE username = $1 AND id != $2',
                [data.username, userId]
            );
            if (clash.rows.length > 0) throw Object.assign(new Error('Username already taken'), { statusCode: 409 });
            fields.push(`username = $${idx++}`);
            values.push(data.username);
        }

        if (fields.length === 0) throw Object.assign(new Error('No fields to update'), { statusCode: 400 });

        values.push(userId);
        const result = await pool.query(
            `UPDATE users SET ${fields.join(', ')}, updated_at = NOW()
             WHERE id = $${idx}
             RETURNING id, name, email, role, home_region, country, created_at, nickname, bio, username,
                       COALESCE(is_b2b_partner, FALSE) as is_b2b_partner`,
            values
        );

        if (result.rows.length === 0) throw Object.assign(new Error('User not found'), { statusCode: 404 });

        const user = result.rows[0];
        return {
            id: user.id,
            name: user.name,
            email: user.email,
            role: user.role,
            homeRegion: user.home_region,
            country: user.country,
            createdAt: user.created_at,
            nickname: user.nickname ?? undefined,
            bio: user.bio ?? undefined,
            username: user.username ?? undefined,
            isB2bPartner: user.is_b2b_partner ?? false,
        };
    }

    // Generate JWT tokens with role
    private generateTokens(userId: string, email: string, role: string): AuthTokens {
        const signOptions: any = {
            expiresIn: process.env.JWT_EXPIRES_IN || '7d'
        };

        const accessToken = jwt.sign(
            { userId, email, role },
            JWT_SECRET,
            signOptions
        );

        const refreshOptions: any = {
            expiresIn: process.env.JWT_REFRESH_EXPIRES_IN || '30d'
        };

        const refreshToken = jwt.sign(
            { userId, email, role },
            JWT_REFRESH_SECRET,
            refreshOptions
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
