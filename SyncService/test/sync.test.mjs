import assert from 'node:assert/strict';
import { generateKeyPairSync, sign } from 'node:crypto';
import { mkdtemp, readFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { afterEach, test } from 'node:test';
import { AppleIdentity } from '../apple.mjs';
import { createSyncServer } from '../server.mjs';
import { SyncStorage } from '../storage.mjs';
import { WeChatIdentity } from '../wechat.mjs';

const resources = [];
afterEach(async () => {
  while (resources.length) {
    const item = resources.pop();
    if (item.server) await new Promise(resolve => item.server.close(resolve));
    item.storage?.close();
    if (item.dir) await rm(item.dir, { recursive: true, force: true });
  }
});
async function fixture() {
  const dir = await mkdtemp(join(tmpdir(), 'trainlog-sync-'));
  const path = join(dir, 'records.db');
  const storage = new SyncStorage(path, Buffer.alloc(32, 7));
  resources.push({ dir, storage });
  return { storage, path };
}
const backup = marker => ({ schemaVersion: 5, exportedAt: new Date().toISOString(), sessions: [{ marker }], exercises: [], templates: [], bodyWeights: [], plans: [], settings: {} });

test('encrypted snapshots use compare-and-swap, isolate accounts, and survive reopening', async () => {
  const { storage, path } = await fixture();
  const a = storage.accountFor('apple', 'subject-a', 'refresh-a');
  const b = storage.accountFor('apple', 'subject-b', 'refresh-b');
  assert.equal(storage.putSnapshot(a, 0, backup('private-heart-rate')).revision, 1);
  assert.deepEqual(storage.putSnapshot(a, 0, backup('stale')), { conflict: true, revision: 1 });
  assert.equal(storage.snapshot(a).backup.sessions[0].marker, 'private-heart-rate');
  assert.equal(storage.snapshot(b).backup, null);
  assert.equal((await readFile(path)).includes(Buffer.from('private-heart-rate')), false);
  assert.equal((await readFile(path)).includes(Buffer.from('subject-a')), false);
  storage.close(); resources.at(-1).storage = null;
  const reopened = new SyncStorage(path, Buffer.alloc(32, 7)); resources.at(-1).storage = reopened;
  assert.equal(reopened.snapshot(a).backup.sessions[0].marker, 'private-heart-rate');
  reopened.deleteAccount(a);
  assert.equal(reopened.snapshot(a).backup, null);
  assert.deepEqual(reopened.refreshTokens(a), []);
});

test('Apple token verification checks signature, audience, issuer, expiry and nonce', async () => {
  const rsa = generateKeyPairSync('rsa', { modulusLength: 2048 });
  const ec = generateKeyPairSync('ec', { namedCurve: 'P-256' });
  const jwk = { ...rsa.publicKey.export({ format: 'jwk' }), kid: 'test-key', use: 'sig' };
  const apple = new AppleIdentity({ clientId: 'app.trainlog.test', teamId: 'TEAM123', keyId: 'KEY123', privateKey: ec.privateKey.export({ format: 'pem', type: 'pkcs8' }).toString(), fetcher: async () => ({ ok: true, json: async () => ({ keys: [jwk] }) }) });
  const encode = value => Buffer.from(JSON.stringify(value)).toString('base64url');
  const token = changes => {
    const now = Math.floor(Date.now() / 1000);
    const content = `${encode({ alg: 'RS256', kid: 'test-key' })}.${encode({ iss: 'https://appleid.apple.com', aud: 'app.trainlog.test', sub: 'account-subject', nonce: 'fresh-nonce', iat: now, exp: now + 300, ...changes })}`;
    return `${content}.${sign('RSA-SHA256', Buffer.from(content), rsa.privateKey).toString('base64url')}`;
  };
  assert.equal(await apple.verifyToken(token({}), 'fresh-nonce'), 'account-subject');
  for (const claims of [{ aud: 'other.app' }, { iss: 'https://imposter.invalid' }, { exp: 1 }, { nonce: 'wrong' }]) await assert.rejects(apple.verifyToken(token(claims), 'fresh-nonce'));
  await assert.rejects(apple.verifyToken(token({}).slice(0, -2) + 'xx', 'fresh-nonce'));
  assert.equal(apple.clientSecret().split('.').length, 3);
});

test('HTTP login never trusts account IDs; snapshot conflicts and sign-out protect data', async () => {
  const { storage } = await fixture();
  const apple = { authenticate: async body => ({ subject: body.identityToken, refreshToken: 'provider-refresh-token' }), revoke: async () => {} };
  const server = createSyncServer({ storage, apple });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  resources.at(-1).server = server;
  const base = `http://127.0.0.1:${server.address().port}`;
  const api = async (path, { method = 'GET', body, token, revision, headers = {} } = {}) => {
    const response = await fetch(base + path, { method, headers: { ...(body ? { 'content-type': 'application/json' } : {}), ...(token ? { authorization: `Bearer ${token}` } : {}), ...(revision !== undefined ? { 'if-match': String(revision) } : {}), ...headers }, body: body ? JSON.stringify(body) : undefined });
    return { status: response.status, value: await response.json() };
  };
  const challenge = (await api('/v1/auth/challenge', { method: 'POST' })).value.nonce;
  const login = await api('/v1/auth/apple', { method: 'POST', body: { nonce: challenge, identityToken: 'user-one', authorizationCode: 'code' } });
  assert.equal(login.status, 200);
  assert.equal((await api('/v1/auth/apple', { method: 'POST', body: { nonce: challenge, identityToken: 'user-one', authorizationCode: 'code' } })).status, 401);
  const first = await api('/v1/snapshot', { method: 'PUT', token: login.value.token, revision: 0, body: backup('only-user-one') });
  assert.equal(first.value.revision, 1);
  assert.equal((await api('/v1/snapshot', { method: 'PUT', token: login.value.token, revision: 0, body: backup('lost-update') })).status, 409);
  assert.equal((await api('/v1/snapshot', { token: login.value.token })).value.backup.sessions[0].marker, 'only-user-one');
  assert.equal((await api('/v1/snapshot', { method: 'PUT', token: login.value.token, body: backup('missing-revision') })).status, 428);
  assert.equal((await api('/v1/snapshot', { method: 'PUT', token: login.value.token, revision: 1, body: { schemaVersion: 99 } })).status, 422);
  const otherNonce = (await api('/v1/auth/challenge', { method: 'POST' })).value.nonce;
  const other = await api('/v1/auth/apple', { method: 'POST', body: { nonce: otherNonce, identityToken: 'user-two', authorizationCode: 'code' } });
  assert.equal((await api('/v1/snapshot', { token: other.value.token })).value.backup, null);
  await api('/v1/auth/logout', { method: 'POST', token: login.value.token });
  assert.equal((await api('/v1/snapshot', { token: login.value.token })).status, 401);
  assert.equal((await api('/v1/account', { token: other.value.token })).value.providers[0], 'apple');
  assert.equal((await api('/v1/account', { method: 'DELETE', token: other.value.token })).status, 428);
  assert.equal((await api('/v1/account', { method: 'DELETE', token: other.value.token, headers: { 'x-confirm-delete': 'DELETE' } })).status, 200);
  assert.equal((await api('/v1/account', { token: other.value.token })).status, 401);
});

test('WeChat login requires a UnionID shared by approved apps', async () => {
  const requests = [];
  const wechat = new WeChatIdentity({ mobileAppId: 'mobile-id', mobileSecret: 'mobile-secret', webAppId: 'web-id', webSecret: 'web-secret', fetcher: async url => {
    requests.push(url);
    return { ok: true, json: async () => url.pathname.endsWith('/access_token')
      ? { access_token: 'short-lived', openid: url.searchParams.get('appid') + '-open-id' }
      : { openid: 'mobile-id-open-id', unionid: 'shared-union-id' } };
  } });
  assert.equal((await wechat.authenticate({ client: 'mobile', code: 'one-time-code' })).subject, 'shared-union-id');
  assert.equal(requests.length, 2);
  assert.equal(requests[0].searchParams.get('appid'), 'mobile-id');
  await assert.rejects(wechat.authenticate({ client: 'unknown', code: 'code' }));
  const noUnionID = new WeChatIdentity({ mobileAppId: 'mobile-id', mobileSecret: 'mobile-secret', fetcher: async url => ({ ok: true, json: async () => url.pathname.endsWith('/access_token') ? { access_token: 'x', openid: 'openid' } : { openid: 'openid' } }) });
  await assert.rejects(noUnionID.authenticate({ client: 'mobile', code: 'code' }), /UnionID/);
});

test('provider linking requires current account authorization and never merges existing accounts', async () => {
  const { storage } = await fixture();
  const apple = { authenticate: async body => ({ subject: body.identityToken, refreshToken: 'refresh-' + body.identityToken }), revoke: async () => {} };
  const wechat = { available: () => true, authenticate: async body => ({ subject: body.code, refreshToken: null }) };
  const server = createSyncServer({ storage, apple, wechat });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  resources.at(-1).server = server;
  const base = `http://127.0.0.1:${server.address().port}`;
  const call = async (path, body, token) => {
    const response = await fetch(base + path, { method: 'POST', headers: { 'content-type': 'application/json', ...(token ? { authorization: `Bearer ${token}` } : {}) }, body: JSON.stringify(body) });
    return { status: response.status, value: await response.json() };
  };
  const challenge = async () => (await call('/v1/auth/challenge', {})).value.nonce;
  const owner = await call('/v1/auth/apple', { nonce: await challenge(), identityToken: 'apple-owner', authorizationCode: 'code' });
  const other = await call('/v1/auth/wechat', { nonce: await challenge(), client: 'mobile', code: 'already-owned' });
  assert.notEqual(owner.value.accountId, other.value.accountId);
  assert.equal((await call('/v1/account/link/wechat', { nonce: await challenge(), client: 'mobile', code: 'already-owned' }, owner.value.token)).status, 409);
  assert.equal((await call('/v1/account/link/wechat', { nonce: await challenge(), client: 'mobile', code: 'new-identity' }, owner.value.token)).status, 200);
  const second = await call('/v1/auth/wechat', { nonce: await challenge(), client: 'web', code: 'new-identity' });
  assert.equal(second.value.accountId, owner.value.accountId);
  assert.equal((await call('/v1/account/link/wechat', { nonce: await challenge(), client: 'mobile', code: 'unlinked' })).status, 401);
});
