/**
 * Middleware to require admin role for protected routes
 */
export const requireAdmin = async (request: any, reply: any) => {
    try {
        await request.jwtVerify();
    } catch (err) {
        return reply.code(401).send({ error: 'Unauthorized', message: 'Invalid token' });
    }

    const userRole = request.user?.role;

    if (userRole !== 'admin') {
        return reply.code(403).send({
            error: 'Forbidden',
            message: 'Admin access required',
        });
    }
};

/**
 * Middleware to require authenticated user (any role)
 */
export const requireAuth = async (request: any, reply: any) => {
    try {
        await request.jwtVerify();
    } catch (err) {
        return reply.code(401).send({ error: 'Unauthorized', message: 'Invalid token' });
    }

    if (!request.user?.userId) {
        return reply.code(401).send({
            error: 'Unauthorized',
            message: 'Authentication required',
        });
    }
};
