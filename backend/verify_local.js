import fs from 'fs';
const BASE_URL = 'http://localhost:3000'; // Localhost

async function log(msg) {
    console.log(msg);
    // Don't write to file for local test, just console
}

async function test() {
    try {
        console.log('--- Local Verification Start ---');

        console.log('1. Health Check...');
        const health = await fetch(`${BASE_URL}/health`);
        const healthData = await health.json();
        console.log(`Health Status: ${health.status}`);

        const email = `verify_local_${Date.now()}@test.com`;
        const password = 'password123';

        console.log(`\n2. Registering ${email}...`);
        const regRes = await fetch(`${BASE_URL}/auth/register`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ name: 'Verifier', email, password })
        });

        // ... (Simplified logic)
        let token;
        if (regRes.status !== 201) {
            const body = await regRes.text();
            console.log(`Register failed body: ${body}`);
        } else {
            const regData = await regRes.json();
            console.log('Register Success. Token obtained.');
            token = regData.tokens?.accessToken;
        }

        if (token) {
            console.log('\n3. Testing Community (Joined)...');
            const commRes = await fetch(`${BASE_URL}/communities/joined`, {
                headers: { 'Authorization': `Bearer ${token}` }
            });
            console.log(`Community Status: ${commRes.status}`);
            const commBody = await commRes.text();
            console.log(`Community Body: ${commBody}`);
        }
    } catch (e) {
        console.log(`ERROR: ${e.message}`);
    }
}

test();
