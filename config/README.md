# config/ —— 策略常量说明

本目录**当前只放说明文档，没有可执行配置，也没有空占位文件**。
配置类常量保留在真正使用它们的位置（脚本/产品 makefile/校验文件），这里是它们
的索引与设计说明，避免同一事实出现两份定义。

## 当前已锁定的策略

| 策略 | 当前值 | 权威位置（单一事实来源） | 验证状态 |
| --- | --- | --- | --- |
| Termux 版本锁定 | v0.118.3（arm64-v8a，官方 debug 签名，35106607 字节） | `scripts/fetch-termux.sh` 顶部常量 + `prebuilt/Termux.apk.sha256` | 哈希/大小已核对上游 release 资产；未构建、未实机验证 |
| 目标分支 | `terminalos/lineage-23.2`（本仓库分支，local manifest 指向） | 仓库分支本身 + `terminalos.mk` 的 `ro.terminalos.branch` | 未构建验证 |
| 静态 overlay 清单 | 仅 `overlay/frameworks/base/core/res/res/values/config.xml`（`config_showNavigationBar=false`） | `terminalos.mk` 的 `PRODUCT_PACKAGE_OVERLAYS` + `overlay/` 目录 | 未构建、未实机验证；Phase 3 需测试手势提示条与 Quick Settings 行为 |
| 预置应用清单 | `TerminalHome`、`Termux` | `terminalos.mk` 的 `PRODUCT_PACKAGES`；`Termux` 模块见 `Android.bp` | 未构建验证 |
| 产品只读标识 | `ro.terminalos.version` / `ro.terminalos.branch` | `terminalos.mk` 的 `PRODUCT_PROPERTY_OVERRIDES` | 未实机验证 |
| 首次启动幂等标记 | `/data/local/terminalos/first_boot.done` | `scripts/first_boot.sh`（参考实现，未接入系统） | 未在设备上执行过 |

## 以后可能放这里的配置

以下只是候选方向，**尚未设计，不要提前建空文件/占位文件**；真正需要时再连同
原因、默认值、验证状态一起加入：

- 锁定任务（locked task）允许列表策略；
- 默认 HOME / 默认桌面选择策略：**方向已定**——不改动/不过滤上游 launcher
  （LineageOS 23.2 默认 `Launcher3QuickStep`），由 TerminalHome 以 Device Owner
  身份 `addPersistentPreferredActivity` 接管（运行时策略，不是产品配置常量，
  因此通常不会落到本目录）；拉起 Termux 使用显式组件
  `com.termux/.app.TermuxActivity`（v0.118.3 已核实）；
- 首次启动初始化的最终策略（接入时机、失败降级、可观测性），与
  `scripts/first_boot.sh` 相关；
- 预置应用白名单与分区选择（system / product / vendor）；
- Termux 插件（如 Termux:Boot）的预置与签名策略；
- 产品只读标识的版本号规则（何时从 `-scaffold` 升级为正式版本）。

## 原则

1. **单一事实来源**：同一常量只在一个文件里定义；需要引用时用相对路径/脚本变量，
   不复制数值。Termux 哈希的两个副本（脚本 + `.sha256` 文件）是刻意的交叉校验，
   由 `scripts/fetch-termux.sh` 强制一致。
2. **不建空文件**：没有实际内容与原因的配置文件不预创建，避免"看起来配了其实没人用"。
3. **写清原因与状态**：每个策略都要能回答"为什么需要 / 验证到哪一步"。
4. **区分只读标识与功能开关**：`ro.*` 属性只用于标识，不作为运行时开关；功能开关
   必须等有测试手段后再加。
