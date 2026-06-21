/**
 * Chat Performance Benchmark — 3 Loops
 *
 * Usage:
 *   JWT_TOKEN=<your_token> node chat_benchmark.js
 *
 * What it does:
 *   Sends a representative set of SEARCH / COOKING / GENERAL messages to the
 *   /api/chat endpoint, times each round-trip, runs 3 loops, and prints a
 *   performance report with per-intent averages and recommendations.
 */

const https = require('https');
const http  = require('http');
const url   = require('url');

// ─────────────────────────────────────────────
// CONFIG — edit these to match your environment
// ─────────────────────────────────────────────
const BASE_URL  = process.env.BASE_URL  || 'http://localhost:5000';
const JWT_TOKEN = process.env.JWT_TOKEN || '';
const LOOPS     = 3;
const TIMEOUT_MS = 30_000;

const TEST_MESSAGES = [
  { label: 'SEARCH-pasta',   message: 'Find me some pasta recipes' },
  { label: 'SEARCH-pantry',  message: 'What can I make with chicken and tomatoes?' },
  { label: 'COOKING-tips',   message: 'How do I know when my steak is medium rare?' },
  { label: 'COOKING-sub',    message: 'Can I substitute butter with olive oil in cookies?' },
  { label: 'GENERAL-cal',    message: 'How many calories are in an avocado?' },
];

// ─────────────────────────────────────────────
// HTTP helper (no external deps required)
// ─────────────────────────────────────────────
function postChat(message) {
  return new Promise((resolve, reject) => {
    const parsed  = url.parse(`${BASE_URL}/api/chat`);
    const payload = JSON.stringify({ message });
    const lib     = parsed.protocol === 'https:' ? https : http;

    const options = {
      hostname: parsed.hostname,
      port:     parsed.port || (parsed.protocol === 'https:' ? 443 : 80),
      path:     parsed.path,
      method:   'POST',
      headers:  {
        'Content-Type':   'application/json',
        'Content-Length': Buffer.byteLength(payload),
        'Authorization':  `Bearer ${JWT_TOKEN}`,
      },
    };

    const req = lib.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => { data += chunk; });
      res.on('end', () => {
        try { resolve({ status: res.statusCode, body: JSON.parse(data) }); }
        catch (_) { resolve({ status: res.statusCode, body: data }); }
      });
    });

    req.on('error', reject);
    req.setTimeout(TIMEOUT_MS, () => { req.destroy(new Error('Request timed out')); });
    req.write(payload);
    req.end();
  });
}

// ─────────────────────────────────────────────
// Benchmark runner
// ─────────────────────────────────────────────
async function runLoop(loopNum) {
  console.log(`\n${'═'.repeat(55)}`);
  console.log(`  LOOP ${loopNum} of ${LOOPS}`);
  console.log(`${'═'.repeat(55)}`);

  const results = [];

  for (const test of TEST_MESSAGES) {
    const t0 = Date.now();
    let status = 0;
    let intent = 'ERR';
    let error  = null;

    try {
      const res = await postChat(test.message);
      status = res.status;
      intent = res.body?.type ?? (res.body?.error ? 'ERR' : '???');
    } catch (e) {
      error = e.message;
    }

    const ms = Date.now() - t0;
    const flag = ms > 5000 ? '🔴' : ms > 2500 ? '🟡' : '🟢';
    console.log(`  ${flag} [${test.label.padEnd(17)}]  ${String(ms).padStart(5)}ms  HTTP:${status}  intent:${intent}${error ? `  ERR:${error}` : ''}`);

    results.push({ label: test.label, ms, status, intent, error });
  }

  return results;
}

function summarise(allResults) {
  console.log(`\n${'═'.repeat(55)}`);
  console.log('  SUMMARY  (avg across all loops)');
  console.log(`${'═'.repeat(55)}`);

  // Group by label
  const byLabel = {};
  for (const r of allResults) {
    (byLabel[r.label] = byLabel[r.label] || []).push(r.ms);
  }

  const intents = { SEARCH: [], COOKING: [], GENERAL: [] };

  for (const [label, times] of Object.entries(byLabel)) {
    const avg = Math.round(times.reduce((a, b) => a + b, 0) / times.length);
    const min = Math.min(...times);
    const max = Math.max(...times);
    const flag = avg > 5000 ? '🔴' : avg > 2500 ? '🟡' : '🟢';
    console.log(`  ${flag} ${label.padEnd(18)}  avg ${String(avg).padStart(5)}ms  (min ${min}ms / max ${max}ms)`);

    const key = label.split('-')[0];
    if (intents[key]) intents[key].push(...times);
  }

  console.log('');
  for (const [intent, times] of Object.entries(intents)) {
    if (times.length === 0) continue;
    const avg = Math.round(times.reduce((a, b) => a + b, 0) / times.length);
    console.log(`  ${intent.padEnd(10)} overall avg: ${avg}ms`);
  }

  console.log(`\n${'─'.repeat(55)}`);
  console.log('  RECOMMENDATIONS');
  console.log(`${'─'.repeat(55)}`);

  const searchAvg  = intents.SEARCH.length  ? Math.round(intents.SEARCH.reduce((a,b)=>a+b,0)  / intents.SEARCH.length)  : 0;
  const cookAvg    = intents.COOKING.length  ? Math.round(intents.COOKING.reduce((a,b)=>a+b,0) / intents.COOKING.length) : 0;
  const generalAvg = intents.GENERAL.length  ? Math.round(intents.GENERAL.reduce((a,b)=>a+b,0) / intents.GENERAL.length) : 0;

  if (searchAvg > 3000)  console.log('  ⚡ SEARCH is slow  → try parallel DB+LLM extraction, or cache popular queries');
  if (cookAvg   > 3000)  console.log('  ⚡ COOKING is slow → reduce max_tokens or switch to llama-3.1-8b-instant for simple questions');
  if (generalAvg > 3000) console.log('  ⚡ GENERAL is slow → reduce max_tokens or cache common nutrition questions');

  const allTimes = allResults.map(r => r.ms);
  const p95 = [...allTimes].sort((a,b)=>a-b)[Math.floor(allTimes.length * 0.95)];
  if (p95 > 5000) console.log('  ⚠️  p95 latency >5s  → add request-level 15s timeout in production');

  const errors = allResults.filter(r => r.error || r.status >= 500);
  if (errors.length > 0) {
    console.log(`  ❌ ${errors.length} error(s) detected — check server logs`);
  } else {
    console.log('  ✅ No errors detected');
  }
  console.log('');
}

// ─────────────────────────────────────────────
// Main
// ─────────────────────────────────────────────
(async () => {
  if (!JWT_TOKEN) {
    console.error('\n❌  JWT_TOKEN env variable is required.');
    console.error('    Get one by logging in, then run:');
    console.error('    JWT_TOKEN=<token> node chat_benchmark.js\n');
    process.exit(1);
  }

  console.log(`\nFoodie AI Chat Benchmark`);
  console.log(`Target : ${BASE_URL}/api/chat`);
  console.log(`Loops  : ${LOOPS}   Messages/loop: ${TEST_MESSAGES.length}   Total: ${LOOPS * TEST_MESSAGES.length}`);

  const allResults = [];
  for (let i = 1; i <= LOOPS; i++) {
    const results = await runLoop(i);
    allResults.push(...results);
    if (i < LOOPS) {
      console.log('  ⏳ Cooling down 2s before next loop…');
      await new Promise(r => setTimeout(r, 2000));
    }
  }

  summarise(allResults);
})();
