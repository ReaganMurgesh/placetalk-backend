const BASE_URL = 'https://placetalk-backend-1.onrender.com';

async function test() {
    try {
        console.log('Checking Node version:', process.version);

        console.log('1. Health Check...');
        const health = await fetch(`${BASE_URL}/health`);
        console.log('Health:', health.status, await health.json());

        const email = `verify_${Date.now()}@test.com`;
        const password = 'password123';

        console.log(`\n2. Registering ${email}...`);
        const regRes = await fetch(`${BASE_URL}/auth/register`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ name: 'Verifier', email, password })
        });

        if (regRes.status !== 201) {
            console.log('Register failed body:', await regRes.text());
        } else {
            const regData = await regRes.json();
            console.log('Register Success. Token obtained.');
            var token = regData.tokens?.accessToken;
        }

        if (!token) {
            throw new Error('No token obtained');
        }

        console.log('\n3. Testing Community (Joined)...');
        const commRes = await fetch(`${BASE_URL}/communities/joined`, {
            headers: { 'Authorization': `Bearer ${token}` }
        });
        const commBody = await commRes.text();
        console.log('Community Status:', commRes.status);
        console.log('Community Body:', commBody.substring(0, 500)); // Truncate if long

        console.log('\n4. Testing Diary (Stats)...');
        const diaryRes = await fetch(`${BASE_URL}/diary/stats`, {
            headers: { 'Authorization': `Bearer ${token}` }
        });
        const diaryBody = await diaryRes.text();
        console.log('Diary Status:', diaryRes.status);
        console.log('Diary Body:', diaryBody.substring(0, 500));

    } catch (e) {
        console.error('ERROR:', e);
    }
}

test();
