/// WeChat's mobile SDK and website QR flow return different OpenIDs. Only a
/// UnionID from applications linked under one Open Platform account is usable
/// as a cross-platform identity.
export class WeChatIdentity {
  constructor({ mobileAppId, mobileSecret, webAppId, webSecret, fetcher = fetch,
    tokenURL = 'https://api.weixin.qq.com/sns/oauth2/access_token', userURL = 'https://api.weixin.qq.com/sns/userinfo' }) {
    this.config = { mobile: [mobileAppId, mobileSecret], web: [webAppId, webSecret] };
    this.fetcher = fetcher; this.tokenURL = tokenURL; this.userURL = userURL;
  }
  available(client) { return !!this.config[client]?.every(Boolean); }
  async authenticate({ code, client }) {
    if (!this.available(client)) throw new Error('WeChat application is not configured');
    if (typeof code !== 'string' || code.length < 1 || code.length > 2048) throw new Error('Invalid WeChat authorization code');
    const [appid, secret] = this.config[client];
    const token = new URL(this.tokenURL);
    token.search = new URLSearchParams({ appid, secret, code, grant_type: 'authorization_code' }).toString();
    const response = await this.fetcher(token);
    if (!response.ok) throw new Error('WeChat authorization code exchange failed');
    const data = await response.json();
    if (data.errcode || typeof data.access_token !== 'string' || typeof data.openid !== 'string') throw new Error('WeChat authorization was rejected');
    let unionID = data.unionid;
    if (!unionID) {
      const user = new URL(this.userURL);
      user.search = new URLSearchParams({ access_token: data.access_token, openid: data.openid }).toString();
      const details = await this.fetcher(user);
      if (!details.ok) throw new Error('WeChat UnionID lookup failed');
      const profile = await details.json();
      if (profile.errcode || profile.openid !== data.openid) throw new Error('WeChat identity mismatch');
      unionID = profile.unionid;
    }
    if (typeof unionID !== 'string' || unionID.length < 1 || unionID.length > 256) throw new Error('WeChat UnionID is required for cross-platform login');
    return { subject: unionID, refreshToken: null };
  }
}
