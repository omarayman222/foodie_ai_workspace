/**
 * Automated chat quality evaluator.
 * Uses LLM-as-judge (Groq) to score each response 1–5.
 *
 * Usage:
 *   node test_quality.js [email] [password]
 *
 * Defaults to the credentials below if not provided via CLI.
 * Exits with code 1 if average score < 3.5.
 */

require('dotenv').config();
const https  = require('https');
const http   = require('http');
const Groq   = require('groq-sdk');

// ── Config ────────────────────────────────────────────────────────────────────
const BASE_URL   = 'http://127.0.0.1:5000/api';
const TEST_EMAIL = process.argv[2] || 'mohamedhassan3m3m3m@gmail.com';
const TEST_PASS  = process.argv[3] || 'yourpassword'; // replace or pass via CLI
const PASS_SCORE = 3.5; // average below this = test suite fails

const groq = new Groq({ apiKey: process.env.GROQ_API_KEY });

// ── Golden test cases ─────────────────────────────────────────────────────────
// Each case has: message, expectedIntent, hint (what the judge should look for)
const TEST_CASES = [
    {
        label:          'COOKING — bread kneading time',
        message:        'How long should I knead bread dough by hand?',
        expectedIntent: 'COOKING',
        hint:           'Should give a specific time range (around 8–10 minutes), not a vague answer.',
        allergies:      [],
    },
    {
        label:          'COOKING — gluten allergy safety',
        message:        'Can I make pasta if I am allergic to gluten?',
        expectedIntent: 'COOKING',
        hint:           'Must NOT suggest regular wheat pasta. Should mention gluten-free alternatives.',
        allergies:      ['gluten'],
    },
    {
        label:          'GENERAL — egg calories',
        message:        'How many calories are in a large egg?',
        expectedIntent: 'GENERAL',
        hint:           'Should contain a specific calorie number close to 70–80 kcal.',
        allergies:      [],
    },
    {
        label:          'GENERAL — honey and diabetes',
        message:        'Is honey safe for someone with diabetes?',
        expectedIntent: 'GENERAL',
        hint:           'Should mention blood sugar / glycaemic impact and recommend moderation or consulting a doctor.',
        allergies:      [],
    },
    {
        label:          'UNCLEAR — greeting',
        message:        'hello there',
        expectedIntent: 'UNCLEAR',
        hint:           'Should ask for clarification (recipe, cooking help, or nutrition). Should NOT give a cooking tip or recipe.',
        allergies:      [],
    },
    {
        label:          'SEARCH — pasta with tomato',
        message:        'I want pasta with tomato sauce',
        expectedIntent: 'SEARCH',
        hint:           'Response type must be SEARCH and should indicate recipes were found.',
        allergies:      [],
    },
    {
        label:          'COOKING — caramelizing onions',
        message:        'How do I properly caramelize onions?',
        expectedIntent: 'COOKING',
        hint:           'Should mention low heat and a time range of 30–40 minutes. Should NOT say 5–10 minutes.',
        allergies:      [],
    },
    {
        label:          'GENERAL — protein in chicken',
        message:        'How much protein is in 100g of chicken breast?',
        expectedIntent: 'GENERAL',
        hint:           'Should give a specific number around 31g of protein per 100g.',
        allergies:      [],
    },
];

// ── HTTP helper ───────────────────────────────────────────────────────────────
function request(method, path, body, token) {
    return new Promise((resolve, reject) => {
        const payload = body ? JSON.stringify(body) : null;
        const opts = {
            hostname: '127.0.0.1',
            port:     5000,
            path:     `/api${path}`,
            method,
            headers: {
                'Content-Type': 'application/json',
                ...(token ? { Authorization: `Bearer ${token}` } : {}),
                ...(payload ? { 'Content-Length': Buffer.byteLength(payload) } : {}),
            },
        };
        const req = http.request(opts, (res) => {
            let data = '';
            res.on('data', chunk => data += chunk);
            res.on('end', () => {
                try { resolve({ status: res.statusCode, body: JSON.parse(data) }); }
                catch (_) { resolve({ status: res.statusCode, body: data }); }
            });
        });
        req.on('error', reject);
        if (payload) req.write(payload);
        req.end();
    });
}

// ── LLM-as-judge ─────────────────────────────────────────────────────────────
async function judgeResponse({ message, reply, hint, allergies, expectedIntent, actualIntent }) {
    const allergyNote = allergies.length > 0
        ? `User allergies: ${allergies.join(', ')}.`
        : 'User has no allergies.';

    const intentNote = expectedIntent === actualIntent
        ? `Intent was correctly classified as ${actualIntent}.`
        : `⚠️ Intent was classified as ${actualIntent} but expected ${expectedIntent}.`;

    const judgePrompt = `You are evaluating a food chatbot response for quality and safety.

Score the response 1–5:
  1 = Completely wrong, unsafe, or ignores a stated allergy
  2 = Partially correct but missing key info or too vague
  3 = Acceptable but could be more specific or helpful
  4 = Correct, practical, and specific
  5 = Excellent — specific, safe, and directly answers the question

${allergyNote}
${intentNote}

User question: "${message}"
What a good answer should include: ${hint}
Chatbot response: "${reply}"

Output ONLY valid JSON, nothing else: {"score": <1-5>, "reason": "<one sentence>"}`;

    try {
        const res = await groq.chat.completions.create({
            messages: [{ role: 'user', content: judgePrompt }],
            model: 'llama-3.1-8b-instant',
            temperature: 0.0,
            max_tokens: 80,
            response_format: { type: 'json_object' },
        });
        const parsed = JSON.parse(res.choices[0].message.content);
        return { score: Number(parsed.score) || 1, reason: parsed.reason || '' };
    } catch (e) {
        return { score: 1, reason: `Judge error: ${e.message}` };
    }
}

// ── Main ──────────────────────────────────────────────────────────────────────
async function main() {
    console.log('\n╔══════════════════════════════════════════════╗');
    console.log('║       Foodie AI — Chat Quality Evaluator     ║');
    console.log('╚══════════════════════════════════════════════╝\n');

    // 1. Login
    process.stdout.write('Logging in... ');
    const loginRes = await request('POST', '/auth/login', { email: TEST_EMAIL, password: TEST_PASS });
    if (loginRes.status !== 200 || !loginRes.body.token) {
        console.error(`FAILED (${loginRes.status}): ${JSON.stringify(loginRes.body)}`);
        console.error('\nHint: pass your credentials as:  node test_quality.js <email> <password>');
        process.exit(1);
    }
    const token = loginRes.body.token;
    console.log('OK\n');

    // 2. Run test cases
    const results = [];

    for (const tc of TEST_CASES) {
        process.stdout.write(`  Testing: ${tc.label} ... `);

        let reply = '';
        let actualIntent = 'ERROR';

        try {
            const chatRes = await request('POST', '/chat', { message: tc.message }, token);
            if (chatRes.status === 200) {
                reply        = chatRes.body.reply || '';
                actualIntent = chatRes.body.type  || 'UNKNOWN';
            } else {
                reply = `[HTTP ${chatRes.status}]`;
            }
        } catch (e) {
            reply = `[Network error: ${e.message}]`;
        }

        const { score, reason } = await judgeResponse({
            message:        tc.message,
            reply,
            hint:           tc.hint,
            allergies:      tc.allergies,
            expectedIntent: tc.expectedIntent,
            actualIntent,
        });

        const icon = score >= 4 ? '✅' : score === 3 ? '⚠️ ' : '❌';
        console.log(`${icon} ${score}/5`);
        console.log(`     Intent: ${actualIntent}${actualIntent !== tc.expectedIntent ? ` (expected ${tc.expectedIntent})` : ''}`);
        console.log(`     Judge:  ${reason}`);
        console.log(`     Reply:  ${reply.slice(0, 120)}${reply.length > 120 ? '…' : ''}\n`);

        results.push({ label: tc.label, score, actualIntent, expectedIntent: tc.expectedIntent });
    }

    // 3. Summary
    const avg = results.reduce((s, r) => s + r.score, 0) / results.length;
    const passed = results.filter(r => r.score >= 4).length;
    const warned = results.filter(r => r.score === 3).length;
    const failed = results.filter(r => r.score <= 2).length;

    console.log('══════════════════════════════════════════════');
    console.log(`  Results:  ✅ ${passed} passed  ⚠️  ${warned} borderline  ❌ ${failed} failed`);
    console.log(`  Average score: ${avg.toFixed(2)} / 5.0`);
    console.log(`  Threshold:     ${PASS_SCORE} / 5.0`);
    console.log('══════════════════════════════════════════════\n');

    if (avg < PASS_SCORE) {
        console.error(`❌ Quality below threshold (${avg.toFixed(2)} < ${PASS_SCORE}). See failures above.\n`);
        console.log('Improvement playbook:');
        console.log('  • Score ≤ 2 on allergy case   → Add allergy list to user message turn, not just system prompt');
        console.log('  • Score ≤ 2 on facts case      → Add "If unsure, say so — do not guess." to system prompt');
        console.log('  • Score ≤ 2 on UNCLEAR case    → Add negative examples to the classifier prompt');
        console.log('  • Response cut off             → Raise max_tokens by 100 in chatController.js');
        console.log('  • Vague answers                → Lower temperature by 0.1 in chatController.js\n');
        process.exit(1);
    } else {
        console.log(`✅ Quality check passed (${avg.toFixed(2)} ≥ ${PASS_SCORE})\n`);
        process.exit(0);
    }
}

main().catch(err => {
    console.error('Unexpected error:', err.message);
    process.exit(1);
});
