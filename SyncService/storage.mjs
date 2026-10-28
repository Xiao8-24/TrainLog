import { createCipheriv, createDecipheriv, createHash, createHmac, hkdfSync, randomBytes, randomUUID } from 'node:crypto';
import { DatabaseSync } from 'node:sqlite';

const hash = value => createHash('sha256').update(value).digest('hex');

export class SyncStorage {
  constructor(path, key) {
    if (!Buffer.isBuffer(key) || key.length !== 32) throw new Error('SYNC_ENCRYPTION_KEY must be 32 bytes');
    this.encryptionKey = Buffer.from(hkdfSync('sha256', key, Buffer.alloc(0), Buffer.from('trainlog.sync.encryption.v1'), 32));
    this.identityKey = Buffer.from(hkdfSync('sha256', key, Buffer.alloc(0), Buffer.from('trainlog.sync.identity.v1'), 32));
    this.db = new DatabaseSync(path);
    this.db.exec(`PRAGMA journal_mode=WAL; PRAGMA synchronous=FULL; PRAGMA foreign_keys=ON;
      CREATE TABLE IF NOT EXISTS accounts(id TEXT PRIMARY KEY, created_at INTEGER NOT NULL);
      CREATE TABLE IF NOT EXISTS identities(provider TEXT NOT NULL, subject TEXT NOT NULL, account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE, PRIMARY KEY(provider,subject));
      CREATE TABLE IF NOT EXISTS sessions(token_hash TEXT PRIMARY KEY, account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE, expires_at INTEGER NOT NULL);
      CREATE TABLE IF NOT EXISTS challenges(nonce_hash TEXT PRIMARY KEY, expires_at INTEGER NOT NULL);
      CREATE TABLE IF NOT EXISTS snapshots(account_id TEXT PRIMARY KEY REFERENCES accounts(id) ON DELETE CASCADE, revision INTEGER NOT NULL, cipher BLOB NOT NULL, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL);
      CREATE TABLE IF NOT EXISTS provider_tokens(provider TEXT NOT NULL, subject TEXT NOT NULL, cipher BLOB NOT NULL, PRIMARY KEY(provider,subject), FOREIGN KEY(provider,subject) REFERENCES identities(provider,subject) ON DELETE CASCADE);`);
  }
  close() { this.db.close(); }
  seal(data, context) {
    const iv = randomBytes(12);
    const cipher = createCipheriv('aes-256-gcm', this.encryptionKey, iv);
    cipher.setAAD(Buffer.from(context));
    const ciphertext = Buffer.concat([cipher.update(data), cipher.final()]);
    return Buffer.concat([iv, cipher.getAuthTag(), ciphertext]);
  }
  open(sealed, context) {
    const decipher = createDecipheriv('aes-256-gcm', this.encryptionKey, sealed.subarray(0, 12));
    decipher.setAAD(Buffer.from(context));
    decipher.setAuthTag(sealed.subarray(12, 28));
    return Buffer.concat([decipher.update(sealed.subarray(28)), decipher.final()]);
  }
  subjectKey(provider, subject) { return createHmac('sha256', this.identityKey).update(provider).update('\0').update(subject).digest('hex'); }
  challenge() {
    const nonce = randomBytes(32).toString('base64url');
    this.db.prepare('INSERT INTO challenges VALUES (?, ?)').run(hash(nonce), Date.now() + 300_000);
    return nonce;
  }
  consumeChallenge(nonce) {
    const result = this.db.prepare('DELETE FROM challenges WHERE nonce_hash=? AND expires_at>?').run(hash(nonce), Date.now());
    return result.changes === 1;
  }
  accountFor(provider, subject, refreshToken) {
    const identifier = this.subjectKey(provider, subject);
    this.db.exec('BEGIN IMMEDIATE');
    try {
      let account = this.db.prepare('SELECT account_id FROM identities WHERE provider=? AND subject=?').get(provider, identifier)?.account_id;
      if (!account) {
        account = randomUUID();
        this.db.prepare('INSERT INTO accounts VALUES (?, ?)').run(account, Date.now());
        this.db.prepare('INSERT INTO identities VALUES (?, ?, ?)').run(provider, identifier, account);
      }
      if (refreshToken) this.db.prepare('INSERT OR REPLACE INTO provider_tokens VALUES (?, ?, ?)').run(provider, identifier, this.seal(Buffer.from(refreshToken), `provider:${provider}:${identifier}`));
      this.db.exec('COMMIT');
      return account;
    } catch (error) { this.db.exec('ROLLBACK'); throw error; }
  }
  hasIdentity(provider, subject) { return !!this.db.prepare('SELECT 1 FROM identities WHERE provider=? AND subject=?').get(provider, this.subjectKey(provider, subject)); }
  linkIdentity(account, provider, subject, refreshToken = null) {
    const identifier = this.subjectKey(provider, subject);
    this.db.exec('BEGIN IMMEDIATE');
    try {
      const owner = this.db.prepare('SELECT account_id FROM identities WHERE provider=? AND subject=?').get(provider, identifier)?.account_id;
      if (owner && owner !== account) { this.db.exec('ROLLBACK'); return false; }
      if (!owner) this.db.prepare('INSERT INTO identities VALUES (?,?,?)').run(provider, identifier, account);
      if (refreshToken) this.db.prepare('INSERT OR REPLACE INTO provider_tokens VALUES (?,?,?)').run(provider, identifier, this.seal(Buffer.from(refreshToken), `provider:${provider}:${identifier}`));
      this.db.exec('COMMIT'); return true;
    } catch (error) { this.db.exec('ROLLBACK'); throw error; }
  }
  issueSession(account) {
    const token = randomBytes(32).toString('base64url');
    const expiresAt = Date.now() + 30 * 24 * 3600_000;
    this.db.prepare('INSERT INTO sessions VALUES (?, ?, ?)').run(hash(token), account, expiresAt);
    return { token, expiresAt };
  }
  accountFromSession(token) {
    if (!/^[A-Za-z0-9_-]{43}$/.test(token)) return null;
    return this.db.prepare('SELECT account_id FROM sessions WHERE token_hash=? AND expires_at>?').get(hash(token), Date.now())?.account_id ?? null;
  }
  revokeSession(token) { this.db.prepare('DELETE FROM sessions WHERE token_hash=?').run(hash(token)); }
  identities(account) { return this.db.prepare('SELECT provider FROM identities WHERE account_id=? ORDER BY provider').all(account).map(row => row.provider); }
  snapshot(account) {
    const row = this.db.prepare('SELECT revision,cipher,updated_at FROM snapshots WHERE account_id=?').get(account);
    return row ? { revision: row.revision, backup: JSON.parse(this.open(row.cipher, `snapshot:${account}:${row.revision}`).toString('utf8')), updatedAt: row.updated_at } : { revision: 0, backup: null, updatedAt: null };
  }
  putSnapshot(account, expectedRevision, backup) {
    const data = Buffer.from(JSON.stringify(backup));
    this.db.exec('BEGIN IMMEDIATE');
    try {
      const current = this.db.prepare('SELECT revision FROM snapshots WHERE account_id=?').get(account)?.revision ?? 0;
      if (current !== expectedRevision) { this.db.exec('ROLLBACK'); return { conflict: true, revision: current }; }
      const next = current + 1, now = Date.now();
      const sealed = this.seal(data, `snapshot:${account}:${next}`);
      this.db.prepare(`INSERT INTO snapshots VALUES (?,?,?,?,?) ON CONFLICT(account_id) DO UPDATE SET revision=excluded.revision,cipher=excluded.cipher,updated_at=excluded.updated_at`).run(account, next, sealed, now, now);
      this.db.exec('COMMIT');
      return { conflict: false, revision: next };
    } catch (error) { this.db.exec('ROLLBACK'); throw error; }
  }
  refreshTokens(account) {
    return this.db.prepare('SELECT provider,subject,cipher FROM provider_tokens JOIN identities USING(provider,subject) WHERE account_id=?').all(account)
      .map(row => ({ provider: row.provider, subject: row.subject, token: this.open(row.cipher, `provider:${row.provider}:${row.subject}`).toString('utf8') }));
  }
  deleteAccount(account) { this.db.prepare('DELETE FROM accounts WHERE id=?').run(account); }
}
