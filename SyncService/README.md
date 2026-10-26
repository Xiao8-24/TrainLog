# TrainLog SyncService（开发内核）

Node 24、无第三方运行依赖。服务默认只监听 `127.0.0.1`，需由独立的 HTTPS 反向代理提供公网访问。当前未配置用户登录界面，也未部署，因此不能作为现有客户端的云同步服务。

```text
cd SyncService
node --test
```

启动前必须在服务端环境变量配置 `SYNC_EXTERNAL_URL=https://你的域名` 与 32 字节随机密钥的 base64 表示 `SYNC_ENCRYPTION_KEY`。`SYNC_DB_PATH` 指向持久化卷；定期备份数据库文件和加密密钥，两者缺一不可。`PORT` 默认 8787。不要把密钥、Apple 私钥、微信 Secret 写入仓库、客户端配置或日志。

Apple 原生登录还需 `APPLE_CLIENT_ID`（iOS App ID）、`APPLE_TEAM_ID`、`APPLE_KEY_ID` 和 `APPLE_PRIVATE_KEY_P8`。Android/Windows 的 Apple 网页授权还需另行注册 Services ID 与 HTTPS 回调，目前未实现网页交接。微信服务端可设置 `WECHAT_MOBILE_APP_ID`/`WECHAT_MOBILE_SECRET` 与 `WECHAT_WEB_APP_ID`/`WECHAT_WEB_SECRET`；客户端仍需通过已审核的 SDK 或扫码流程取得一次性授权码。多端应用须挂在同一个微信开放平台账户下以取得可互通的 UnionID。

接口：`POST /v1/auth/challenge`、`POST /v1/auth/apple`、`POST /v1/auth/wechat`、`GET /v1/account`、`POST /v1/account/link/apple`、`POST /v1/account/link/wechat`、`POST /v1/auth/logout`、`GET|PUT /v1/snapshot`、`DELETE /v1/account`。写入快照必须提供 `If-Match` 整数版本，冲突返回 409；读取和写入均需要 `Authorization: Bearer`。公共服务不得以测试身份或硬编码密钥代替平台认证。

**上线前仍需**：域名与 HTTPS、登录平台应用审核、客户端授权界面及安全令牌存储、请求限速和监控、健康资料单独同意、隐私政策和保存期限、账户删除完整体验、真实设备与安全测试。云端当前只做整个备份的条件写入，尚不适合默认后台自动同步；并发冲突需由用户处理，不能静默覆盖。详见 [设计与状态](../Documentation/ACCOUNT_SYNC.md)。
