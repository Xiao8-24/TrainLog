import { createPrivateKey, createPublicKey, sign, verify } from 'node:crypto';

const decode = value => JSON.parse(Buffer.from(value, 'base64url').toString('utf8'));
const encode = value => Buffer.from(JSON.stringify(value)).toString('base64url');

export class AppleIdentity {
  constructor({ clientId, teamId, keyId, privateKey, fetcher = fetch, keysURL = 'https://appleid.apple.com/auth/keys', tokenURL = 'https://appleid.apple.com/auth/token', revokeURL = 'https://appleid.apple.com/auth/revoke' }) {
    if (!clientId || !teamId || !keyId || !privateKey) throw new Error('Apple developer configuration is incomplete');
    this.clientId = clientId; this.teamId = teamId; this.keyId = keyId;
    this.privateKey = createPrivateKey(privateKey.replaceAll('\\n', '\n'));
    this.fetcher = fetcher; this.keysURL = keysURL; this.tokenURL = tokenURL; this.revokeURL = revokeURL;
    this.cachedKeys = null; this.keysExpireAt = 0;
  }
  clientSecret() {
    const now = Math.floor(Date.now() / 1000);
    const head = encode({ alg: 'ES256', kid: this.keyId, typ: 'JWT' });
    const body = encode({ iss: this.teamId, iat: now, exp: now + 30 * 24 * 3600, aud: 'https://appleid.apple.com', sub: this.clientId });
    const content = `${head}.${body}`;
    return `${content}.${sign('sha256', Buffer.from(content), { key: this.privateKey, dsaEncoding: 'ieee-p1363' }).toString('base64url')}`;
  }
  async keys() {
    if (this.cachedKeys && Date.now() < this.keysExpireAt) return this.cachedKeys;
    const response = await this.fetcher(this.keysURL);
    if (!response.ok) throw new Error('Apple public key lookup failed');
    const body = await response.json();
    if (!Array.isArray(body.keys)) throw new Error('Apple key response is invalid');
    this.cachedKeys = body.keys; this.keysExpireAt = Date.now() + 3600_000;
    return this.cachedKeys;
  }
  async verifyToken(token, nonce) {
    const parts = token?.split('.');
    if (parts?.length !== 3 || parts.some(part => !part)) throw new Error('Invalid Apple identity token');
    let header, claims;
    try { header = decode(parts[0]); claims = decode(parts[1]); } catch { throw new Error('Invalid Apple token encoding'); }
    if (header.alg !== 'RS256' || typeof header.kid !== 'string') throw new Error('Unsupported Apple token signature');
    const key = (await this.keys()).find(candidate => candidate.kid === header.kid && candidate.kty === 'RSA' && candidate.use === 'sig');
    if (!key || !verify('RSA-SHA256', Buffer.from(`${parts[0]}.${parts[1]}`), createPublicKey({ key, format: 'jwk' }), Buffer.from(parts[2], 'base64url'))) throw new Error('Apple token signature is invalid');
    const now = Math.floor(Date.now() / 1000);
    if (claims.iss !== 'https://appleid.apple.com' || claims.aud !== this.clientId || typeof claims.sub !== 'string' || !claims.sub || claims.nonce !== nonce || !Number.isSafeInteger(claims.iat) || claims.iat > now + 60 || !Number.isSafeInteger(claims.exp) || claims.exp <= now) throw new Error('Apple token claims are invalid');
    return claims.sub;
  }
  async exchange(code) {
    const response = await this.fetcher(this.tokenURL, { method: 'POST', headers: { 'content-type': 'application/x-www-form-urlencoded' }, body: new URLSearchParams({ client_id: this.clientId, client_secret: this.clientSecret(), code, grant_type: 'authorization_code' }) });
    if (!response.ok) throw new Error('Apple authorization code exchange failed');
    const body = await response.json();
    if (typeof body.id_token !== 'string') throw new Error('Apple token exchange response is invalid');
    return body;
  }
  async authenticate({ identityToken, authorizationCode, nonce }) {
    const subject = await this.verifyToken(identityToken, nonce);
    const exchanged = await this.exchange(authorizationCode);
    if (await this.verifyToken(exchanged.id_token, nonce) !== subject) throw new Error('Apple authorization mismatch');
    return { subject, refreshToken: exchanged.refresh_token ?? null };
  }
  async revoke(refreshToken) {
    const response = await this.fetcher(this.revokeURL, { method: 'POST', headers: { 'content-type': 'application/x-www-form-urlencoded' }, body: new URLSearchParams({ client_id: this.clientId, client_secret: this.clientSecret(), token: refreshToken, token_type_hint: 'refresh_token' }) });
    if (!response.ok) throw new Error('Apple token revocation failed');
  }
}
