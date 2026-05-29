#!/usr/bin/env node
'use strict';

const http = require('http');
const https = require('https');

const host = '127.0.0.1';
const port = Number(process.env.DEEPSEEK_PROXY_PORT || 17860);
const apiKey = process.env.DEEPSEEK_API_KEY || '';
const model = process.env.DEEPSEEK_MODEL || 'deepseek-v4-flash';
const baseUrl = (process.env.DEEPSEEK_BASE_URL || 'https://api.deepseek.com').replace(/\/+$/, '');
const isSiliconFlow = /siliconflow\.(cn|com)/i.test(baseUrl);
const reasoningByToolCallId = new Map();
const fs = require('fs');
const logFile = process.env.DEEPSEEK_PROXY_LOG || '';

function log(message) {
  const line = `[deepseek-proxy] ${message}`;
  console.error(line);
  if (logFile) {
    try { fs.appendFileSync(logFile, `${new Date().toISOString()} ${line}\n`, 'utf8'); } catch {}
  }
}

function sendJson(res, status, body) {
  const text = JSON.stringify(body);
  res.writeHead(status, {
    'content-type': 'application/json; charset=utf-8',
    'content-length': Buffer.byteLength(text)
  });
  res.end(text);
}

function readJson(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on('data', chunk => chunks.push(chunk));
    req.on('end', () => {
      try {
        const raw = Buffer.concat(chunks).toString('utf8');
        resolve(raw ? JSON.parse(raw) : {});
      } catch (error) {
        reject(error);
      }
    });
    req.on('error', reject);
  });
}

function contentToText(content) {
  if (typeof content === 'string') return content;
  if (!Array.isArray(content)) return '';
  const parts = [];
  for (const block of content) {
    if (!block) continue;
    if (typeof block === 'string') {
      parts.push(block);
    } else if (block.type === 'text') {
      parts.push(block.text || '');
    } else if (block.type === 'tool_result') {
      const value = typeof block.content === 'string' ? block.content : JSON.stringify(block.content || '');
      parts.push(`Tool result for ${block.tool_use_id || 'tool'}:\n${value}`);
    } else if (block.type === 'image') {
      parts.push('[image omitted]');
    }
  }
  return parts.filter(Boolean).join('\n');
}

function toOpenAiMessages(body) {
  const result = [];
  if (body.system) {
    result.push({ role: 'system', content: contentToText(body.system) });
  }
  for (const message of body.messages || []) {
    if (message.role === 'user' && Array.isArray(message.content)) {
      const toolResults = message.content.filter(x => x && x.type === 'tool_result');
      const otherBlocks = message.content.filter(x => !x || x.type !== 'tool_result');
      for (const block of toolResults) {
        const value = typeof block.content === 'string' ? block.content : JSON.stringify(block.content || '');
        result.push({
          role: 'tool',
          tool_call_id: block.tool_use_id,
          content: value || ''
        });
      }
      const text = contentToText(otherBlocks);
      if (text) {
        result.push({ role: 'user', content: text });
      }
      continue;
    }

    if (message.role === 'assistant' && Array.isArray(message.content)) {
      const text = message.content.filter(x => x && x.type === 'text').map(x => x.text || '').join('\n');
      const toolUses = message.content.filter(x => x && x.type === 'tool_use');
      if (toolUses.length) {
        const openaiMessage = {
          role: 'assistant',
          content: text || null,
          tool_calls: toolUses.map(tool => ({
            id: tool.id,
            type: 'function',
            function: {
              name: tool.name,
              arguments: JSON.stringify(tool.input || {})
            }
          }))
        };
        const reasoning = toolUses.map(tool => reasoningByToolCallId.get(tool.id)).filter(Boolean).join('\n');
        if (reasoning) {
          openaiMessage.reasoning_content = reasoning;
        }
        result.push(openaiMessage);
      } else {
        result.push({ role: 'assistant', content: text });
      }
    } else {
      result.push({
        role: message.role === 'assistant' ? 'assistant' : 'user',
        content: contentToText(message.content)
      });
    }
  }
  return result;
}

function toOpenAiTools(tools) {
  if (!Array.isArray(tools) || !tools.length) return undefined;
  return tools.map(tool => ({
    type: 'function',
    function: {
      name: tool.name,
      description: tool.description || '',
      parameters: tool.input_schema || { type: 'object', properties: {} }
    }
  }));
}

function callDeepSeek(payload) {
  return new Promise((resolve, reject) => {
    const url = new URL(`${baseUrl}/chat/completions`);
    const body = JSON.stringify(payload);
    const req = https.request(url, {
      method: 'POST',
      timeout: 90000,
      headers: {
        authorization: `Bearer ${apiKey}`,
        'content-type': 'application/json',
        'content-length': Buffer.byteLength(body)
      }
    }, res => {
      const chunks = [];
      res.on('data', chunk => chunks.push(chunk));
      res.on('end', () => {
        const text = Buffer.concat(chunks).toString('utf8');
        let json = {};
        try { json = text ? JSON.parse(text) : {}; } catch { json = { raw: text }; }
        if (res.statusCode >= 400) {
          const message = json.error && json.error.message ? json.error.message : `DeepSeek HTTP ${res.statusCode}`;
          const error = new Error(message);
          error.statusCode = res.statusCode;
          error.body = json;
          reject(error);
          return;
        }
        resolve(json);
      });
    });
    req.on('timeout', () => req.destroy(new Error('DeepSeek request timed out')));
    req.on('error', reject);
    req.write(body);
    req.end();
  });
}

function toAnthropic(openai, requestModel) {
  const choice = openai.choices && openai.choices[0] ? openai.choices[0] : {};
  const message = choice.message || {};
  const content = [];
  const reasoning = message.reasoning_content || '';
  if (message.content) {
    content.push({ type: 'text', text: message.content });
  }
  for (const call of message.tool_calls || []) {
    if (reasoning && call.id) {
      reasoningByToolCallId.set(call.id, reasoning);
    }
    let input = {};
    try { input = JSON.parse(call.function && call.function.arguments ? call.function.arguments : '{}'); } catch {}
    content.push({
      type: 'tool_use',
      id: call.id || `toolu_${Date.now()}`,
      name: call.function ? call.function.name : 'tool',
      input
    });
  }
  if (!content.length) content.push({ type: 'text', text: '' });
  return {
    id: openai.id || `msg_${Date.now()}`,
    type: 'message',
    role: 'assistant',
    model: openai.model || requestModel,
    content,
    stop_reason: message.tool_calls && message.tool_calls.length ? 'tool_use' : (choice.finish_reason === 'length' ? 'max_tokens' : 'end_turn'),
    stop_sequence: null,
    usage: {
      input_tokens: openai.usage && openai.usage.prompt_tokens ? openai.usage.prompt_tokens : 0,
      output_tokens: openai.usage && openai.usage.completion_tokens ? openai.usage.completion_tokens : 0
    }
  };
}

function sendSse(res, message) {
  res.writeHead(200, {
    'content-type': 'text/event-stream; charset=utf-8',
    'cache-control': 'no-cache',
    connection: 'keep-alive'
  });
  const send = (event, data) => {
    res.write(`event: ${event}\n`);
    res.write(`data: ${JSON.stringify(data)}\n\n`);
  };
  send('message_start', { type: 'message_start', message: { ...message, content: [] } });
  message.content.forEach((block, index) => {
    const startBlock = block.type === 'text'
      ? { type: 'text', text: '' }
      : { type: 'tool_use', id: block.id, name: block.name, input: {} };
    send('content_block_start', { type: 'content_block_start', index, content_block: startBlock });
    if (block.type === 'text' && block.text) {
      send('content_block_delta', { type: 'content_block_delta', index, delta: { type: 'text_delta', text: block.text } });
    } else if (block.type === 'tool_use') {
      send('content_block_delta', {
        type: 'content_block_delta',
        index,
        delta: {
          type: 'input_json_delta',
          partial_json: JSON.stringify(block.input || {})
        }
      });
    }
    send('content_block_stop', { type: 'content_block_stop', index });
  });
  send('message_delta', {
    type: 'message_delta',
    delta: { stop_reason: message.stop_reason, stop_sequence: null },
    usage: { output_tokens: message.usage.output_tokens }
  });
  send('message_stop', { type: 'message_stop' });
  res.end();
}

async function handleMessages(req, res) {
  if (!apiKey || apiKey.includes('replace_with')) {
    sendJson(res, 401, { type: 'error', error: { type: 'authentication_error', message: 'DEEPSEEK_API_KEY is missing.' } });
    return;
  }
  const body = await readJson(req);
  const requestModel = body.model || model;
  const payload = {
    model: requestModel,
    messages: toOpenAiMessages(body),
    max_tokens: Math.min(Number(body.max_tokens || 4096), 8192),
    stream: false
  };
  if (isSiliconFlow) {
    payload.enable_thinking = false;
  } else {
    payload.thinking = { type: 'disabled' };
  }
  if (typeof body.temperature === 'number') payload.temperature = body.temperature;
  if (typeof body.top_p === 'number') payload.top_p = body.top_p;
  const tools = toOpenAiTools(body.tools);
  if (tools) payload.tools = tools;
  log(`request model=${requestModel} messages=${payload.messages.length} tools=${tools ? tools.length : 0} stream=${!!body.stream}`);
  const openai = await callDeepSeek(payload);
  const firstChoice = openai.choices && openai.choices[0] ? openai.choices[0] : {};
  const firstMessage = firstChoice.message || {};
  if (firstMessage.tool_calls && firstMessage.tool_calls.length) {
    for (const call of firstMessage.tool_calls) {
      const args = call.function && call.function.arguments ? call.function.arguments : '';
      log(`tool_call id=${call.id || ''} name=${call.function ? call.function.name : ''} args=${args.slice(0, 500)}`);
    }
  }
  const anthropic = toAnthropic(openai, requestModel);
  if (body.stream) sendSse(res, anthropic);
  else sendJson(res, 200, anthropic);
}

const server = http.createServer(async (req, res) => {
  try {
    const url = new URL(req.url, `http://${req.headers.host || `${host}:${port}`}`);
    if (req.method === 'GET' && url.pathname === '/health') {
      sendJson(res, 200, { ok: true, model, baseUrl });
      return;
    }
    if (req.method === 'GET' && (url.pathname === '/v1/models' || url.pathname === '/models')) {
      const modelList = isSiliconFlow
        ? [
          { id: 'deepseek-ai/DeepSeek-V4-Flash', object: 'model', owned_by: 'siliconflow' },
          { id: 'deepseek-ai/DeepSeek-V4-Pro', object: 'model', owned_by: 'siliconflow' }
        ]
        : [
          { id: 'deepseek-v4-flash', object: 'model', owned_by: 'deepseek' },
          { id: 'deepseek-v4-pro', object: 'model', owned_by: 'deepseek' }
        ];
      sendJson(res, 200, {
        object: 'list',
        data: modelList
      });
      return;
    }
    if (req.method === 'POST' && (url.pathname === '/v1/messages' || url.pathname === '/messages')) {
      await handleMessages(req, res);
      return;
    }
    sendJson(res, 404, { type: 'error', error: { type: 'not_found_error', message: 'Not found' } });
  } catch (error) {
    log(`error: ${error.message}`);
    sendJson(res, error.statusCode || 500, {
      type: 'error',
      error: {
        type: 'api_error',
        message: error.message || String(error)
      }
    });
  }
});

server.listen(port, host, () => {
  log(`listening http://${host}:${port}, forwarding ${baseUrl}/chat/completions, model=${model}`);
});
