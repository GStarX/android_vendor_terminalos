# prebuilt/ —— 预置二进制说明（Termux）

本目录存放 TerminalOS 需要的**预置二进制 APK**。当前只有一个：

| 应用 | 上游 | 版本 | 资产 | 大小 | 签名 |
| --- | --- | --- | --- | --- | --- |
| Termux | `termux/termux-app` | v0.118.3 | `termux-app_v0.118.3+github-debug_arm64-v8a.apk` | 35106607 字节 | Termux 官方 GitHub Actions debug 签名 |

- 下载地址（URL 中的 `%2B` 即 `+`）：
  <https://github.com/termux/termux-app/releases/download/v0.118.3/termux-app_v0.118.3%2Bgithub-debug_arm64-v8a.apk>
- SHA256（已与官方 release 的 `sha256sums` 资产逐字核对）：

  ```text
  72fdb596045116bf5ba1b5bdf5b26fddb9acc0bd074ad9f2da9eb0ae85e83a4e
  ```

- 期望文件布局：

  ```text
  prebuilt/Termux.apk          # 不入库（.gitignore 忽略），脚本下载
  prebuilt/Termux.apk.sha256   # 入库，sha256sum 格式："<sha256>  Termux.apk"
  ```

## 为什么二进制不入库

1. **体积与历史**：35 MB 的 APK 进 git 会让仓库膨胀且永久留在历史里，替换版本还会
   再翻倍；构建产物不应该出现在源码仓库。
2. **可审计来源**：文件必须来自上游官方 release，用锁定的 SHA256 描述，而不是
   某台构建机上的副本。入库反而让"这份 APK 到底从哪来"变得不可追踪。
3. **许可证与再分发**：Termux 是上游项目，本仓库只做"锁定版本 + 校验后预置"，
   不重新分发不可确认的二进制包。
4. **不可重建**：该 APK 由上游 CI 签名，我们无法在本地重建出逐字节相同的文件，
   所以只能"固定引用 + 校验"，不能当作可编译产物。

## 如何获取

在本仓库根目录执行（需要网络访问 GitHub release 资产）：

```bash
bash scripts/fetch-termux.sh            # 已存在且校验通过则跳过（幂等）
bash scripts/fetch-termux.sh --force    # 强制重新下载（例如怀疑文件损坏时）
```

脚本行为：

- 从上面的锁定 URL 下载到 `prebuilt/Termux.apk`；
- 先校验**大小 = 35106607 字节**，再校验 **SHA256**；
- **同时**校验脚本内硬编码的期望哈希与 `prebuilt/Termux.apk.sha256` 一致，
  两者不一致直接失败（防止有人只改了一处）；
- 任何失败都以非零状态退出，并清理半成品临时文件（`*.apk.part`）；
- 成功后打印 APK 的绝对路径。

## 校验策略

- **大小 + SHA256 双重校验**：大小能立刻发现截断的下载，SHA256 保证字节一致。
- **锁定的哈希有两个副本**：`scripts/fetch-termux.sh` 里的 `TERMUX_SHA256` 与
  `prebuilt/Termux.apk.sha256`。脚本要求两者一致后才下载/使用，避免出现
  "文件里换了版本、脚本里没换"的漂移。
- 手动复核（Linux 构建机上可直接用 sha256sum）：

  ```bash
  cd prebuilt && sha256sum -c Termux.apk.sha256
  ```

- **禁止重新签名 / 禁止二次打包**：该 APK 是 Termux 官方 debug 签名，不是 AOSP
  平台签名。`Android.bp` 用 `android_app_import { presigned: true }` 原样预置；
  重新签名会改变字节、使校验失效，并影响与 Termux 官方插件（如 Termux:Boot）
  的签名兼容性。
- **只接受上游官方资产**：不允许从第三方镜像、网盘或"某人给的文件"获取；也不允许
  手工改 APK。找不到官方资产时应停下并上报，而不是换来源。

## 升级流程（换版本时必须全部完成）

1. 确认上游发布了新版本，并取得**官方 release 资产**的 SHA256（官方 `sha256sums`
   资产或 release 页面）。
2. 更新 `scripts/fetch-termux.sh` 顶部四个常量：
   `TERMUX_VERSION`、`TERMUX_URL`、`TERMUX_SHA256`、`TERMUX_SIZE_BYTES`。
3. 同步更新 `prebuilt/Termux.apk.sha256`（格式：`<sha256>  Termux.apk`）。
4. 删除旧文件并重新执行 `bash scripts/fetch-termux.sh`，确认脚本成功退出且打印路径。
5. 在 GitHub 上查看新版本 release notes，确认**签名主体没变**（仍是 Termux 官方
   CI debug 签名）；签名变化会让预置假设失效，需单独评审。
6. 在下面的"版本历史"登记：版本、SHA256、日期、升级原因、验证状态。
7. 不要提交 APK 本身；只提交脚本、`.sha256` 文件和本 README 的变更。

**未在真机验证**：升级后必须在设备上确认 Termux 能正常启动、bootstrap 能安装、
终端可交互。当前整个仓库都是"待构建验证"状态，任何版本升级如实标注为未验证。

## 版本历史

| 版本 | SHA256（前 16 位） | 大小（字节） | 说明 | 验证状态 |
| --- | --- | --- | --- | --- |
| v0.118.3 | `72fdb596045116bf` | 35106607 | 初始锁定：TerminalOS 首个预置版本，取上游最新正式发布，arm64-v8a 资产 | 哈希/大小已核对上游资产；未构建、未实机验证 |

## 未验证声明

本目录只描述"锁定哪个上游资产、如何校验、如何升级"。Termux 作为系统预置应用在
Android 16 / LineageOS 23.2 上的安装与运行行为**尚未构建验证、尚未实机测试**。
