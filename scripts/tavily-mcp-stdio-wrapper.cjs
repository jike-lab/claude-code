#!/usr/bin/env node
'use strict';

const https = require('https');
const readline = require('readline');
const REMOTE_URL = 'https://mcp.api-inference.modelscope.net/76c78438d7634d/mcp';

let sessionId = null;
let remoteVersion = '2024-11-05';

function remoteRpc(body) {
  return new Promise((resolve, reject) => {
    const headers = { 'Content-Type': 'application/json', 'Accept': 'application/json, text/event-stream' };
    if (sessionId) headers['Mcp-Session-Id'] = sessionId;
    const req = https.request(REMOTE_URL, { method: 'POST', headers }, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        const ns = res.headers['mcp-session-id'];
        if (ns && typeof ns === 'string') sessionId = ns;
        resolve(data || null);
      });
    });
    req.on('error', reject);
    req.write(body);
    req.end();
  });
}

async function ensureSession() {
  if (sessionId) return;
  const resp = await remoteRpc(JSON.stringify({ jsonrpc: '2.0', id: 1, method: 'initialize', params: { protocolVersion: '2024-11-05', capabilities: {}, clientInfo: { name: 'tavily-wrapper', version: '1.0' } } }));
  if (resp) {
    try { const j = JSON.parse(resp); if (j.result?.protocolVersion) remoteVersion = j.result.protocolVersion; } catch {}
  }
  await remoteRpc(JSON.stringify({ jsonrpc: '2.0', method: 'notifications/initialized' }));
}

const rl = readline.createInterface({ input: process.stdin, crlfDelay: Infinity });

rl.on('line', async (line) => {
  const t = line.trim();
  if (!t) return;

  let req;
  try { req = JSON.parse(t); } catch { return; }
  const { id, method, params } = req;

  try {
    switch (method) {
      case 'initialize': {
        await ensureSession();
        process.stdout.write(JSON.stringify({
          jsonrpc: '2.0', id,
          result: {
            protocolVersion: remoteVersion,
            capabilities: { experimental: {}, prompts: { listChanged: false }, resources: { subscribe: false, listChanged: false }, tools: { listChanged: false } },
            serverInfo: { name: 'tavily-wrapper', version: '1.0' }
          }
        }) + '\n');
        break;
      }
      case 'notifications/initialized':
        break;
      case 'ping':
        process.stdout.write(JSON.stringify({ jsonrpc: '2.0', id, result: {} }) + '\n');
        break;
      case 'tools/list': {
        await ensureSession();
        const resp = await remoteRpc(JSON.stringify({ jsonrpc: '2.0', id, method: 'tools/list' }));
        process.stdout.write((resp || JSON.stringify({ jsonrpc: '2.0', id, error: { code: -32603, message: 'no response' } })) + '\n');
        break;
      }
      case 'tools/call': {
        await ensureSession();
        const resp = await remoteRpc(JSON.stringify({ jsonrpc: '2.0', id, method: 'tools/call', params: { name: params.name, arguments: params.arguments } }));
        process.stdout.write((resp || JSON.stringify({ jsonrpc: '2.0', id, error: { code: -32603, message: 'no response' } })) + '\n');
        break;
      }
      default:
        process.stdout.write(JSON.stringify({ jsonrpc: '2.0', id, error: { code: -32601, message: `unknown method: ${method}` } }) + '\n');
    }
  } catch (e) {
    process.stdout.write(JSON.stringify({ jsonrpc: '2.0', id, error: { code: -32603, message: e.message } }) + '\n');
  }
});

rl.on('close', () => process.exit(0));
