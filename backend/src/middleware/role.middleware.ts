import type { Request, Response, NextFunction } from 'fastify';

/**
 * Middleware to require admin role for protected routes
 */
export const requireAdmin = (request: any, reply: any, done: Function) => {
    const userRole = request.user?.role;

    if (userRole !== 'admin') {
        return reply.code(403).send({
            error: 'Forbidden',
            message: 'Admin access required',
        });
    }

    done();
};

/**
 * Middleware to require authenticated user (any role)
 */
export const requireAuth = (request: any, reply: any, done: Function) => {
    if (!request.user?.userId) {
        return reply.code(401).send({
            error: 'Unauthorized',
            message: 'Authentication required',
        });
    }

    done();
};
