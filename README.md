# android_vendor_terminalos

TerminalOS 的 Android 产品配置仓库：为 Xiaomi MIX 2S（`polaris`，SDM845）提供
预置应用、静态 overlay 与产品标识，目标版本 **LineageOS 23.2 / Android 16**
（实验性；上游 LineageOS 对 polaris 的官方支持停在 22.2）。

> **状态：脚手架（scaffolding），未构建验证、未刷机验证。**
> 当前没有 Linux 构建机，内核与闭源 blobs 也都没有 23.2 分支，因此本仓库还没有
> 参与过任何成功构建。本文档中的所有构建步骤都是流程说明，不代表已在项目上执行成功。

## 仓库目的

在**不 fork 上游设备树**的前提下，把 TerminalOS 的产品差异集中到一个可独立演进、
可一键回滚的仓库里：

- 预置终端环境（Termux，官方 APK 原样预置）；
- 预置 TerminalHome（模块来自独立仓库）；
- 用静态 overlay 做最小的框架资源覆盖；
- 提供可审计的预置二进制获取/校验脚本（SHA256 锁定，二进制不入库）；
- 提供（尚未接入系统的）首次启动初始化参考实现。

## 目录结构

```text
android_vendor_terminalos/            # 挂载到 $TOP/vendor/terminalos
├── terminalos.mk                     # 产品片段：PRODUCT_PACKAGES / overlay / 只读属性
├── Android.bp                        # Termux 预置模块（android_app_import, presigned）
├── .gitignore                        # 忽略 prebuilt/*.apk（二进制不入库）
├── .gitattributes                    # 统一 LF 换行；*.apk 标记为 binary
├── README.md                         # 本文件
├── config/
│   └── README.md                     # 策略常量索引（Termux 版本锁定、目标分支、overlay 清单）
├── docs/
│   └── integration.md                # 集成说明：引用链、lunch target、回滚、未验证声明
├── overlay/
│   └── frameworks/base/core/res/res/values/
│       └── config.xml                # 静态 overlay：config_showNavigationBar=false
├── prebuilt/
│   ├── README.md                     # 为什么不入库 / 如何获取 / 校验与升级流程
│   └── Termux.apk.sha256             # 锁定的 SHA256（"<sha256>  Termux.apk"）
└── scripts/
    ├── fetch-termux.sh               # 下载 Termux APK 并校验大小 + SHA256（构建前必跑）
    └── first_boot.sh                 # 首次启动初始化参考实现（未接入 init）
```

`prebuilt/Termux.apk` 本身**不在仓库里**，由 `scripts/fetch-termux.sh` 下载并校验。

## 与上游的关系

| 上游仓库 | 分支/状态 | 说明 |
| --- | --- | --- |
| `LineageOS/android`（主 manifest） | 有 `lineage-23.2` | 目标平台版本 |
| `LineageOS/android_device_xiaomi_polaris` | 有 `lineage-23.2`（SHA `1b46255`，内容与 22.2 相同） | 设备树；我们的 `terminalos_polaris.mk` 在其上层复用 |
| `LineageOS/android_kernel_xiaomi_sdm845` | **最高 `lineage-22.2`**，无 23.2 | Android 16 依赖缺失之一 |
| `TheMuppets/proprietary_vendor_xiaomi_polaris` | 只到 `lineage-22.2` | 闭源 blobs 依赖缺失之一 |
| `TheMuppets/proprietary_vendor_xiaomi_sdm845-common` | 只到 `lineage-22.2` | 同上 |

本仓库通过 local manifest 挂载：

```xml
<project name="GStarX/android_vendor_terminalos"
         path="vendor/terminalos"
         revision="terminalos/lineage-23.2" />
```

设备树侧（不在本仓库）的集成契约见 [`docs/integration.md`](docs/integration.md)：
`terminalos_polaris.mk` 先复用 `lineage_polaris.mk`，再继承本仓库的
`terminalos.mk`，并设置 `PRODUCT_NAME := terminalos_polaris`。

## 快速开始（说明用，未在本项目验证）

```bash
# 1. 构建前必须：下载并校验预置 Termux APK（二进制不入库）
bash vendor/terminalos/scripts/fetch-termux.sh

# 2. 标准 LineageOS 构建流程（与设备树 TERMINALOS_BRANCH.md 一致；本项目未执行过）
source build/envsetup.sh
lunch terminalos_polaris-userdebug
brunch terminalos_polaris
```

- lunch target：**`terminalos_polaris-userdebug`**
- 若第 1 步没做，Soong 会因 `prebuilt/Termux.apk` 缺失直接报错（预期行为，避免
  用未校验的 APK 构建）。
- `scripts/fetch-termux.sh` 是幂等的：校验通过则跳过；`--force` 强制重新下载。
- 脚本需要 `bash`、`curl`/`wget`、`sha256sum`/`shasum`；Git 提交时请保留可执行位
  （构建机上 `chmod +x scripts/*.sh`）。

## 当前状态

已完成（仅脚手架/静态审查）：

- 产品片段、预置模块定义、静态 overlay、只读产品标识；
- Termux 版本锁定（v0.118.3）、SHA256/大小校验脚本与说明文档；
- 首次启动初始化参考实现（明确未接入系统）；
- 集成说明、配置索引、回滚说明。

未完成 / 未验证：

- **未构建**：没有任何 system 镜像产物；
- **未实机验证**：Termux 预置、overlay、属性、首启动脚本均未在 Android 16 上跑过；
- 内核与 blobs 无 23.2 上游分支（当前无法构建的根本原因）；
- 设备树 23.2 与 22.2 内容相同，上游尚未针对 Android 16 适配 polaris；
- 首次启动初始化未接入任何 init 流程（需 Phase 2 设计评审）；
- 默认 HOME 接管（TerminalHome Device Owner）与 TerminalHome → Termux 拉起未实现
  （方向已定，见下）；产品配置层不删除/不过滤上游 launcher。

## 待验证项

1. `fetch-termux.sh` 在 Linux 构建机上的下载/校验/幂等/失败路径（含代理与限速场景）。
2. Soong 能否正确构建 `android_app_import`（`presigned: true` + 关闭 dex_preopt），
   APK 是否原样进入 system 镜像且 SHA256 不变。
3. Termux 在 Android 16 上的首次启动、bootstrap 初始化与终端可用性（含 targetSdk
   兼容性、存储/电池优化限制）。
4. 静态 overlay 是否生效：`config_showNavigationBar=false` 后手势导航、手势提示条、
   Quick Settings 触控区域的行为（MIX 2S 无实体导航键，风险较高）。
5. `ro.terminalos.version` / `ro.terminalos.branch` 是否出现在最终系统属性中。
6. 整机能否启动（受内核/blobs 缺失限制，优先级最高也最不确定）。
7. TerminalHome 以 Device Owner 身份 `addPersistentPreferredActivity` 接管默认 HOME，
   以及用显式组件 `com.termux/.app.TermuxActivity` 拉起 Termux（Phase 2 实现，
   未实现、未验证；产品配置层不删除上游 launcher）。

## 回滚方式

目标是回到纯上游 `lineage_polaris`：

1. 删除设备树里的 TerminalOS 产品入口（或整个 `terminalos_polaris.mk`）：去掉
   `$(call inherit-product, vendor/terminalos/terminalos.mk)` 与
   `PRODUCT_NAME := terminalos_polaris`；
2. 从 local manifest 移除 `vendor/terminalos` 条目；
3. `lunch lineage_polaris-userdebug` 后重新构建；
4. 建议 `make clobber` 或至少 `installclean` 清理跨产品残留（常规做法，未验证）；
5. 可选：删除 `vendor/terminalos` 与 `prebuilt/Termux.apk`。

本仓库不安装运行时 RRO、不接入开机脚本，回滚不会留下系统级副作用。

## 相关文档

- [集成说明](docs/integration.md) —— 引用链、lunch target、构建前步骤、首启动、回滚
- [预置二进制说明](prebuilt/README.md) —— 为什么不入库、校验策略、升级流程
- [策略常量索引](config/README.md) —— 当前锁定值、单一事实来源、以后可能放这里的配置
- `overlay/frameworks/base/core/res/res/values/config.xml` —— 唯一 overlay 内容与风险说明

## 待决策（需要 Lead / 产品侧确认）

1. 是否预置 **Termux:Boot**（同签名要求 + 额外版本锁定）。
2. 隐藏导航栏后的返回/主页操作入口方案（手势导航 vs TerminalHome 自带操作区）。
3. 首次启动初始化的接入方式与 SELinux 策略归属。

已决定方向（尚未实现）：**不删除/不过滤上游启动器**（LineageOS 23.2 默认
`Launcher3QuickStep`，来自 `common_mobile.mk`），默认 HOME 由 TerminalHome 以
Device Owner 身份 `addPersistentPreferredActivity` 接管；拉起 Termux 使用显式组件
`com.termux/.app.TermuxActivity`（v0.118.3 已核实）。
