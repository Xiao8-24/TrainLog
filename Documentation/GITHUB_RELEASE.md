# 没有 Mac 时的云端构建与发布

项目使用 GitHub 托管的 macOS runner 执行 Xcode，Windows 端不需要安装 Xcode。源码中不包含证书、Apple 账号或访问令牌。

主构建使用 `xcode-27` 镜像与 Xcode 27.0 / iOS 27 SDK；独立 `macos-15` / Xcode 16.4 任务回归 iOS 18。两组测试成功才发布。缺少 iOS 27 环境时不会回退并冒充新系统验收。

## 发布步骤

1. 在自己的 GitHub 账号下创建 TrainLog 仓库并上传完整目录，包括 `.github`、`Packages` 和 `TrainLog.xcodeproj`。
2. 打开 **Actions → TrainLog build and release**，首次 push 会运行检查、业务测试、iOS 模拟器测试和未签名设备归档。
3. 如果失败，在该次运行下载 `TrainLog-diagnostics-*`，检查 `core-tests.log`、`ios-tests.log`、`archive.log` 和 `.xcresult`。修复后重新推送。红色失败状态不能视为完成构建。
4. 成功后，可以从 `TrainLog-delivery-*` 下载源码和未签名 IPA。
5. 发布版本：选择 **Run workflow**，选要发布的分支，勾选 `publish`，输入尚未使用的版本号（例如 `v0.3.0`）。流程会重新测试，并且只在全部成功后为同一提交创建 GitHub 预览版 Release。
6. Release 附件保留在版本页面；Actions 的临时构建/诊断附件保留 14 天。发布流程只在发布 job 中使用 `contents: write`，PR 测试没有发布权限。

不要把 ZIP 文件本身当作仓库源码上传；工作流必须位于仓库根目录的 `.github/workflows/ios.yml`。不要给已有 tag 改指向；已发布版本应使用新版本号。

## iPhone 安装和商店发布

GitHub Release 发布的是项目及构建文件，无法代替 Apple 签名。`TrainLog-unsigned.ipa` 是未签名归档包装，不能直接在 iPhone 安装。后续若配置有效的开发/分发证书、私钥和对应 provisioning profile，可以另行接入签名流程；证书和私钥应使用受控 secrets，不应放入源码或聊天。TestFlight/App Store 还需要对应的 Apple 开发者与 App Store Connect 配置。

参考：[GitHub 工作流权限](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax)、[Apple 证书用途](https://developer.apple.com/help/account/certificates/certificates-overview/)、[向注册设备分发](https://developer.apple.com/documentation/xcode/distributing-your-app-to-registered-devices)。

当前文档描述的是已配置的流程；只有真实 GitHub Actions 成功记录才能证明项目已编译和测试通过。
