import fs from 'fs';
const BASE_URL = 'https://placetalk-backend-1.onrender.com';

async function log(msg) {
    console.log(msg);
    fs.appendFileSync('backend/verify_output.txt', msg + '\n');
}

async function test() {
    try {
        fs.writeFileSync('backend/verify_output.txt', '--- Verification Start ---\n');

        await log(`Checking Node version: ${process.version}`);

        await log('1. Health Check...');
        const health = await fetch(`${BASE_URL}/health`);
        const healthData = await health.json();
        await log(`Health Status: ${health.status}`);

        if (healthData.timestamp) {
            const serverTime = new Date(healthData.timestamp);
            const now = new Date();
            const ageMinutes = (now.getTime() - serverTime.getTime()) / 1000 / 60;
            await log(`Server Timestamp: ${healthData.timestamp}`);
            await log(`Server Age: ${ageMinutes.toFixed(1)} minutes`);
        } else {
            await log(`Health Data: ${JSON.stringify(healthData)}`);
        }

        const email = `verify_${Date.now()}@test.com`;
        const password = 'password123';

        await log(`\n2. Registering ${email}...`);
        const regRes = await fetch(`${BASE_URL}/auth/register`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ name: 'Verifier', email, password })
        });

        let token;
        if (regRes.status !== 201) {
            const body = await regRes.text();
            await log(`Register failed body: ${body}`);
        } else {
            const regData = await regRes.json();
            await log('Register Success. Token obtained.');
            token = regData.tokens?.accessToken;
        }

        if (token) {
            await log('\n3. Testing Community (Joined)...');
            const commRes = await fetch(`${BASE_URL}/communities/joined`, {
                headers: { 'Authorization': `Bearer ${token}` }
            });
            await log(`Community Status: ${commRes.status}`);
            const commBody = await commRes.text();
            await log(`Community Body: ${commBody}`);

            await log('\n4. Testing Diary (Stats)...');
            const diaryRes = await fetch(`${BASE_URL}/diary/stats`, {
                headers: { 'Authorization': `Bearer ${token}` }
            });
            await log(`Diary Status: ${diaryRes.status}`);
            const diaryBody = await diaryRes.text();
            await log(`Diary Body: ${diaryBody}`);
        } else {
            await log('Skipping protected tests (No Token)');
        }

    } catch (e) {
        await log(`ERROR: ${e.message}`);
        await log(e.stack);
    }
}

test();
