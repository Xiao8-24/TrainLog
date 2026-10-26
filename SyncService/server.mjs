import { createServer } from 'node:http';
import { fileURLToPath } from 'node:url';
import { resolve } from 'node:path';
import { AppleIdentity } from './apple.mjs';
import { SyncStorage } from './storage.mjs';

const maximumBody = 32 * 1024 * 1024;

function send(response, status, body) {
  response.writeHead(status, { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store', 'x-content-type-options': 'nosniff' });
  response.end(JSON.stringify(body));
}
async function readJSON(request) {
  if (!request.headers['content-type']?.startsWith('application/json')) throw Object.assign(new Error('JSON required'), { status: 415 });
  let size = 0; const parts = [];
  for await (const part of request) {
    size += part.length;
    if (size > maximumBody) throw Object.assign(new Error('Backup exceeds 32 MB'), { status: 413 });
    parts.push(part);
  }
  try { return JSON.parse(Buffer.concat(parts).toString('utf8')); }
  catch { throw Object.assign(new Error('Invalid JSON'), { status: 400 }); }
}
function validBackup(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value) || !Number.isInteger(value.schemaVersion) || value.schemaVersion < 1 || value.schemaVersion > 5) return false;
  return Array.isArray(value.sessions) && Array.isArray(value.exercises) && Array.isArray(value.templates) && Array.isArray(value.bodyWeights) && value.settings && typeof value.settings === 'object';
}
function sessionAccount(request, storage) {
  const match = /^Bearer ([A-Za-z0-9_-]{43})$/.exec(request.headers.authorization ?? '');
  return match ? storage.accountFromSession(match[1]) : null;
}

export function createSyncServer({ storage, apple = null }) {
  return createServer(async (request, response) => {
    try {
      const path = new URL(request.url, 'http://localhost').pathname;
      if (request.method === 'GET' && path === '/health') return send(response, 200, { status: 'ok' });
      if (request.method === 'POST' && path === '/v1/auth/challenge') {
        if (!apple) return send(response, 503, { error: 'Apple login is not configured' });
        return send(response, 200, { nonce: storage.challenge(), expiresInSeconds: 300 });
      }
      if (request.method === 'POST' && path === '/v1/auth/apple') {
        if (!apple) return send(response, 503, { error: 'Apple login is not configured' });
        const body = await readJSON(request);
        if (!body || typeof body !== 'object' || ![body.nonce, body.identityToken, body.authorizationCode].every(value => typeof value === 'string' && value.length > 0 && value.length < 8192)) return send(response, 400, { error: 'Invalid Apple authorization' });
        if (!storage.consumeChallenge(body.nonce)) return send(response, 401, { error: 'Challenge expired or reused' });
        let identity;
        try { identity = await apple.authenticate(body); }
        catch { return send(response, 401, { error: 'Apple authorization was not verified' }); }
        if (!identity.refreshToken && !storage.hasIdentity('apple', identity.subject)) return send(response, 401, { error: 'Apple refresh token is required for account creation' });
        const account = storage.accountFor('apple', identity.subject, identity.refreshToken);
        return send(response, 200, { accountId: account, ...storage.issueSession(account) });
      }
      const account = sessionAccount(request, storage);
      if (!account) return send(response, 401, { error: 'Sign in required' });
      if (request.method === 'GET' && path === '/v1/account') return send(response, 200, { accountId: account, providers: storage.identities(account) });
      if (request.method === 'POST' && path === '/v1/auth/logout') {
        storage.revokeSession(request.headers.authorization.slice(7));
        return send(response, 200, { signedOut: true });
      }
      if (request.method === 'GET' && path === '/v1/snapshot') return send(response, 200, storage.snapshot(account));
      if (request.method === 'PUT' && path === '/v1/snapshot') {
        const match = /^(0|[1-9][0-9]*)$/.exec(request.headers['if-match'] ?? '');
        if (!match || !Number.isSafeInteger(Number(match[1]))) return send(response, 428, { error: 'If-Match revision required' });
        const backup = await readJSON(request);
        if (!validBackup(backup)) return send(response, 422, { error: 'Unsupported backup shape' });
        const result = storage.putSnapshot(account, Number(match[1]), backup);
        return send(response, result.conflict ? 409 : 200, result);
      }
      if (request.method === 'DELETE' && path === '/v1/account') {
        if (request.headers['x-confirm-delete'] !== 'DELETE') return send(response, 428, { error: 'Explicit deletion confirmation required' });
        if (!apple) return send(response, 503, { error: 'Provider revocation is unavailable' });
        for (const provider of storage.refreshTokens(account)) {
          if (provider.provider !== 'apple') return send(response, 503, { error: 'Provider revocation is unavailable' });
          await apple.revoke(provider.token);
        }
        storage.deleteAccount(account);
        return send(response, 200, { deleted: true });
      }
      return send(response, 404, { error: 'Not found' });
    } catch (error) {
      const status = Number.isInteger(error.status) && error.status >= 400 && error.status < 500 ? error.status : 500;
      if (status === 500) console.error('Sync request failed:', error.message);
      if (!response.headersSent) send(response, status, { error: status === 500 ? 'Server error' : error.message });
      else response.destroy();
    }
  });
}

if (process.argv[1] && fileURLToPath(import.meta.url) === resolve(process.argv[1])) {
  const encodedKey = process.env.SYNC_ENCRYPTION_KEY ?? '';
  const key = Buffer.from(encodedKey, 'base64');
  if (key.length !== 32 || !process.env.SYNC_EXTERNAL_URL?.startsWith('https://')) {
    console.error('Set a 32-byte base64 SYNC_ENCRYPTION_KEY and HTTPS SYNC_EXTERNAL_URL before starting.');
    process.exit(1);
  }
  const apple = ['APPLE_CLIENT_ID', 'APPLE_TEAM_ID', 'APPLE_KEY_ID', 'APPLE_PRIVATE_KEY_P8'].every(name => process.env[name])
    ? new AppleIdentity({ clientId: process.env.APPLE_CLIENT_ID, teamId: process.env.APPLE_TEAM_ID, keyId: process.env.APPLE_KEY_ID, privateKey: process.env.APPLE_PRIVATE_KEY_P8 }) : null;
  const storage = new SyncStorage(process.env.SYNC_DB_PATH ?? './trainlog-sync.db', key);
  const host = process.env.SYNC_BIND_HOST ?? '127.0.0.1';
  const port = Number(process.env.PORT ?? '8787');
  createSyncServer({ storage, apple }).listen(port, host, () => console.log(`TrainLog sync listening on ${host}:${port}`));
}
