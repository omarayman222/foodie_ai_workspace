const fs   = require('fs');
const path = require('path');

const LOG_FILE = path.join(__dirname, '../../chat_quality.log');

function log({ intent, message, reply, ms }) {
    const line = JSON.stringify({
        ts:      new Date().toISOString(),
        intent:  intent || 'UNKNOWN',
        ms:      ms || 0,
        message: (message || '').slice(0, 200),
        reply:   (reply   || '').slice(0, 500),
    });
    fs.appendFile(LOG_FILE, line + '\n', () => {}); // fire-and-forget, never blocks response
}

module.exports = { log };
