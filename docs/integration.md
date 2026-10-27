# TerminalOS 集成说明（android_vendor_terminalos）

> **状态声明：未构建验证、未刷机验证。**
> 本文描述的是设计意图与集成契约。当前没有 Linux 构建机，也缺少 LineageOS 23.2
> 的内核/闭源 blobs 分支，因此本仓库的所有内容都处于"待构建验证"状态。文中出现的
> 构建命令是标准 LineageOS 流程的说明，**不代表在本项目上执行成功过**。

## 1. 仓库定位

- 本仓库：`GStarX/android_vendor_terminalos`，分支 `terminalos/lineage-23.2`
- 挂载路径：`$TOP/vendor/terminalos`（通过 local manifest 引入）
- 产品：TerminalOS / 目标设备 Xiaomi MIX 2S（`polaris`，SDM845）
- 目标版本：LineageOS 23.2 / Android 16（**实验性**；上游 LineageOS 对 polaris 的
  官方支持停在 22.2）

本仓库**只提供产品配置片段**：预置应用清单、静态 overlay、只读产品标识、
预置二进制的获取/校验脚本，以及（未接入的）首次启动参考实现。它**不**提供
设备树、内核、blobs，也不设置 `PRODUCT_NAME`——这些由设备树负责。

## 2. 如何被 device 树引用

引用链（从 lunch 到本仓库）：

```text
lunch terminalos_polaris-userdebug
  -> device/xiaomi/polaris/terminalos_polaris.mk        (设备树，不在本仓库)
       -> $(call inherit-product, device/xiaomi/polaris/lineage_polaris.mk)  (复用上游)
       -> $(call inherit-product, vendor/terminalos/terminalos.mk)           (本仓库)
            -> PRODUCT_PACKAGES += TerminalHome Termux
            -> PRODUCT_PACKAGE_OVERLAYS += vendor/terminalos/overlay
            -> PRODUCT_PROPERTY_OVERRIDES += ro.terminalos.version / branch
  -> 上游 lineage_polaris.mk 继续继承 device.mk 与
     vendor/lineage/config/common_full_phone.mk，并设置 PRODUCT_NAME := lineage_polaris
```

关键约定：

- 设备树里的 `terminalos_polaris.mk` 必须在复用上游 `lineage_polaris.mk` **之后**
  再选择本仓库片段，并设置 `PRODUCT_NAME := terminalos_polaris`（`lunch` 目标的
  前半段就是 `PRODUCT_NAME`）。本仓库**不**改 `PRODUCT_NAME`、`PRODUCT_DEVICE`、
  `PRODUCT_BRAND`，避免与设备树冲突。
- local manifest 示意（实际清单由构建侧维护，不在本仓库）：

  ```xml
  <project name="GStarX/android_vendor_terminalos"
           path="vendor/terminalos"
           revision="terminalos/lineage-23.2" />
  ```

- 模块名 `TerminalHome` 与 `Termux` 是产品契约：`PRODUCT_PACKAGES` 里引用的是
  Soong 模块名。`Termux` 由本仓库 `Android.bp` 定义；`TerminalHome` 由 TerminalHome
  的独立仓库定义（预期挂载到 `packages/apps/TerminalHome`，同样需写进 local
  manifest），本仓库不提供其源码。
- 静态 overlay 的相对路径按 `$TOP` 解析，因此写作 `vendor/terminalos/overlay`
  （仓库内对应 `overlay/` 目录）。

## 3. 构建前必须做的事

1. **先拉取并校验 Termux APK**（否则 Soong 会因缺少 `prebuilt/Termux.apk` 直接报错）：

   ```bash
   bash vendor/terminalos/scripts/fetch-termux.sh
   ```

   - APK 不入库，由脚本从 Termux 官方 release 下载；
   - 校验锁定大小 35106607 字节 + SHA256；
   - 幂等：已存在且校验通过会跳过；`--force` 强制重新下载；
   - 失败以非零退出，构建不应在未通过校验的 APK 上继续。

2. 同步 local manifest，确保以下仓库都在树里：设备树、内核、blobs、TerminalHome、
   本仓库。

3. 标准 LineageOS 构建流程（说明用，未在本项目执行过；与设备树
   `TERMINALOS_BRANCH.md` 记录的命令一致）：

   ```bash
   source build/envsetup.sh
   lunch terminalos_polaris-userdebug
   brunch terminalos_polaris
   ```

   （`brunch <product>` 是 LineageOS 的标准封装；等价于 `mka bacon`。）

4. 构建产物应位于 `out/target/product/polaris/`。

## 4. lunch target

- **`terminalos_polaris-userdebug`**
- 由设备树 `terminalos_polaris.mk` 里的 `PRODUCT_NAME := terminalos_polaris` 决定；
  本仓库不定义该变量。
- 如果 lunch 列表里没有该目标，先检查 local manifest 与设备树是否就位，而不是改
  本仓库。

## 5. Termux 预置 ≠ 初始化完成

预置 Termux 只做了一件事：把上游官方 APK 原样放进系统分区（`android_app_import`，
`presigned: true`）。以下**都没有**做，也不在本次脚手架范围内：

- Termux 首次启动时的 bootstrap 解压/初始化、存储权限、电池优化豁免；
- Termux 内部的包源（mirror）选择与依赖安装；
- `Termux:Boot`、`Termux:API` 等插件（官方插件必须与 Termux 同签名才有完整
  互操作能力；若要预置，需要单独评审签名与 SHA256 锁定）；
- 与 TerminalHome 的默认 HOME / 启动入口联动（方向已定，见 5.1；实现未验证）；
- 锁定任务（locked task）等策略。

因此"Termux 已预置"只代表 APK 在系统镜像里，**不代表终端环境已经可用**。
用户首次打开 Termux 时仍会发生初始化行为；在 Android 16 上的实际表现未验证。

### 5.1 启动器与默认 HOME（已决定方向，尚未实现）

- 上游 LineageOS 23.2 的默认启动器是 **`Launcher3QuickStep`**（来自
  `vendor/lineage/config/common_mobile.mk`；另有 `Launcher3QuickStepGo` /
  `Launcher3Overlay` 变体）。
- **决定：产品配置不删除、不过滤、不替换任何启动器。** `terminalos.mk` 里没有
  也没有必要写 launcher 相关的移除逻辑；launcher 组件清单继续由上游
  `common_mobile.mk` 维护。
- 默认 HOME 的接管方式是**运行时策略**：TerminalHome 以 Device Owner 身份调用
  `DevicePolicyManager.addPersistentPreferredActivity` 把自己设为默认 HOME。
  这属于 Phase 2 实现，当前未实现、未验证。
- 需要拉起 Termux 时，使用显式组件 **`com.termux/.app.TermuxActivity`**
  （Termux v0.118.3 已核实），不要用隐式 ACTION_MAIN intent。

## 6. 首次启动初始化（参考实现，未接入系统）

- 文件：`scripts/first_boot.sh`
- **没有被任何 init.rc / service / 开机广播触发**，不会自动执行；README 与脚本
  头部都注明了这一点，接入前必须做 Phase 2 设计评审。
- 幂等标记：`/data/local/terminalos/first_boot.done`
  - 标记存在 → 直接退出 0，不重复写日志；
  - 标记不存在 → 只创建 `/data/local/terminalos` 与 `logs/`，追加一条启动日志，
    最后用"临时文件 + rename"写标记。
- 失败策略：所有失败只写 stderr 并退出 0，**不得阻塞开机**。
- 不联网、不安装 bootstrap、不改 Termux 数据、不调用 pm/am。
- 接入前需要单独解决：`/data` 挂载/解密时机、`/data/local/terminalos` 的 SELinux
  file context、user 版本上的可写性、失败可观测性（logcat 而非 stderr）。

手工试跑方式（仅示意，未在设备上验证）：在 userdebug 设备上
`adb shell su -c 'sh /data/local/tmp/first_boot.sh'`，连续执行两次，第二次应输出
`already initialized` 并跳过。

## 7. 静态 overlay

- `PRODUCT_PACKAGE_OVERLAYS += vendor/terminalos/overlay`
- 当前唯一内容：`overlay/frameworks/base/core/res/res/values/config.xml` 中
  `<bool name="config_showNavigationBar">false</bool>`（隐藏底部导航条）。
- `config_showNavigationBar` 是 AOSP `frameworks/base` 的真实资源名，原样覆盖，
  没有猜测其他资源。
- **未实机验证**：MIX 2S 无实体导航键，隐藏导航条后的手势导航、手势提示条、
  Quick Settings 触控行为都需要 Phase 3 实机测试；有问题时删除该 `<bool>` 条目
  重新构建即可回滚。
- 静态 overlay 需要重新生成 system 镜像才生效，不能靠 `rro` 命令动态开关。

## 8. 只读产品标识

`terminalos.mk` 里定义（均为 `ro.*`，property service 启动后只读，不是功能开关）：

| 属性 | 值 | 说明 |
| --- | --- | --- |
| `ro.terminalos.version` | `0.1.0-scaffold` | 脚手架阶段版本标识 |
| `ro.terminalos.branch` | `terminalos/lineage-23.2` | 产品配置分支 |

这些属性名由本仓库新定义，不与其他组件冲突；目前没有任何组件读取它们，
未实机验证。**不要**在这里加未经测试的功能开关。

## 9. 与上游的关系（已核实的上游状态）

- 设备树 `LineageOS/android_device_xiaomi_polaris`：`lineage-23.2` 分支存在
  （SHA `1b46255`），内容与 `lineage-22.2` 相同；其 `lineage_polaris.mk` 完成
  `device.mk` 与 `vendor/lineage/config/common_full_phone.mk` 继承，
  `PRODUCT_NAME := lineage_polaris`。
- LineageOS `android` 主 manifest：存在 `lineage-23.2` 分支。
- 内核 `LineageOS/android_kernel_xiaomi_sdm845`：**最高只有 `lineage-22.2`**，没有
  `lineage-23.2`；`arch/arm64/configs/vendor/xiaomi/polaris.config` 存在。
- 闭源 blobs：`TheMuppets/proprietary_vendor_xiaomi_polaris` 与
  `TheMuppets/proprietary_vendor_xiaomi_sdm845-common` 都只到 `lineage-22.2`。

结论：23.2 的"内核 + blobs"两条依赖当前不存在上游分支，这是本项目目前无法构建
的根本原因，不是本仓库的配置问题。设备树 23.2 与 22.2 内容相同，说明上游尚未针对
Android 16 实际适配 polaris，因此我们在 23.2 上能否构建出可启动系统仍是未知数。

## 10. 回滚

目标是"回到纯上游 LineageOS polaris（22.2 或上游 23.2）"：

1. 删除设备树中的产品入口（或删除整个 `terminalos_polaris.mk`）：
   - 去掉 `$(call inherit-product, vendor/terminalos/terminalos.mk)` 与
     `PRODUCT_NAME := terminalos_polaris`；
2. 从 local manifest 移除 `vendor/terminalos` 的 project 条目；
3. `lunch lineage_polaris-userdebug`（或上游对应目标）后重新构建；
4. 建议 `make clobber` 或至少 `installclean` 清理跨产品残留（未验证，属常规做法）；
5. 可选：删除 `vendor/terminalos` 目录与 `prebuilt/Termux.apk`（二进制随时可由脚本
   重新获取）。

本仓库没有任何系统级副作用会残留到回滚之后（无开机脚本接入、无运行时 RRO 安装）。

## 11. 未验证声明（再次强调）

- 本仓库**未参与任何成功构建**，未生成过 system 镜像；
- Termux 预置、静态 overlay、产品属性、首次启动脚本均**未在 Android 16 /
  LineageOS 23.2 真机上验证**；
- 内核与 blobs 的 22.2 上限意味着即使构建通过也不能直接推断可启动/可用；
- 所有状态以"待构建验证"记录，直到有 Linux 构建机并产出可验证镜像。

## 12. 已决定的设计方向与待决策问题

已决定（尚未实现，均未验证）：

- **启动器**：不在产品配置里删除/过滤 Launcher3QuickStep 等上游启动器；默认 HOME
  由 TerminalHome 以 Device Owner 身份 `addPersistentPreferredActivity` 接管。
- **拉起 Termux**：使用显式组件 `com.termux/.app.TermuxActivity`（v0.118.3 已核实）。

待决策（需要 Lead / 产品侧拍板）：

1. 是否预置 **Termux:Boot**（需要与 Termux 同签名，并引入额外版本锁定与 SHA256）。
2. 隐藏导航栏后，TerminalOS 的返回/主页操作入口用什么方案（手势导航？TerminalHome
   自带操作区？），这决定 overlay 是否保留。
3. 首次启动初始化最终接入方式（init service / 开机广播 / app 自检），以及
   `/data/local/terminalos` 的 SELinux 策略归属。
