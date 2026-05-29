#!/usr/bin/env node
'use strict';

const https = require('https');
const API_KEY = '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';

function search(query, opts = {}) {
  return new Promise((resolve, reject) => {
    const data = JSON.stringify({
      api_key: API_KEY,
      query,
      search_depth: opts.search_depth || 'basic',
      topic: opts.topic || 'general',
      max_results: opts.max_results || 10,
      include_answer: opts.include_answer || false,
      include_raw_content: opts.include_raw_content || false,
      include_images: opts.include_images || false,
      days: opts.days || 3,
    });

    const req = https.request('https://api.tavily.com/search', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' }
    }, (res) => {
      let body = '';
      res.on('data', chunk => body += chunk);
      res.on('end', () => {
        try { resolve(JSON.parse(body)); }
        catch (e) { reject(new Error(`Parse error: ${e.message}`)); }
      });
    });
    req.on('error', reject);
    req.write(data);
    req.end();
  });
}

async function main() {
  const args = process.argv.slice(2);
  const mode = args[0] || 'search';
  const query = args[1];

  if (!query) {
    console.error('Usage: node tavily-search.cjs [search|extract] <query> [max_results]');
    process.exit(1);
  }

  try {
    if (mode === 'search') {
      const result = await search(query, { max_results: parseInt(args[2]) || 10 });
      process.stdout.write(JSON.stringify(result, null, 2));
    } else if (mode === 'extract') {
      const { default: fetch } = await import('node-fetch');
      const resp = await fetch('https://api.tavily.com/extract', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ api_key: API_KEY, urls: [query] })
      });
      const data = await resp.json();
      process.stdout.write(JSON.stringify(data, null, 2));
    }
  } catch (e) {
    console.error('Error:', e.message);
    process.exit(1);
  }
}

main();
