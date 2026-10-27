# terminalos.mk
#
# TerminalOS 产品片段（product makefile fragment）
# 目标设备：Xiaomi MIX 2S（polaris / SDM845）
# 目标版本：LineageOS 23.2 / Android 16（实验性，官方支持只到 22.2）
#
# 本文件由设备树中的 terminalos_polaris.mk 继承：
#   $(call inherit-product, vendor/terminalos/terminalos.mk)
# 前提：本仓库通过 local manifest 挂载到 $TOP/vendor/terminalos，
#       指向 GStarX/android_vendor_terminalos 的 terminalos/lineage-23.2 分支。
#
# 状态：脚手架（scaffolding）。未构建、未刷机、未实机验证。
# 这里只放已确认必需且影响面最小的条目，每段都注明原因与验证状态。
# 禁止在本文件删除或替换 SystemUI / Settings 等系统组件——这些仍由上游
# vendor/lineage/config/common_full_phone.mk 提供，本片段只做"增加"。
#
# 语法约定：
#   - product makefile 在 $TOP 被 include，因此这里的相对路径一律相对 $TOP，
#     本仓库的 overlay 写作 vendor/terminalos/overlay（仓库内目录为 overlay/）。
#   - 只引用本文件、上游 product 配置或构建系统已定义的变量；本片段故意不
#     定义任何中间变量，避免出现未定义变量。

# ---------------------------------------------------------------------------
# 预置应用
# ---------------------------------------------------------------------------
# TerminalHome
#   为什么需要：TerminalOS 的默认桌面/入口应用，必须随系统预置，不能依赖
#   用户从第三方商店安装。模块名 "TerminalHome" 由 TerminalHome 的独立仓库
#   提供（预期挂载到 packages/apps/TerminalHome，同样需要写进 local manifest；
#   Soong 模块名必须正好是 TerminalHome，这是产品契约）。
#   验证状态：未构建。若设备树/清单里缺 TerminalHome 仓库，构建会在
#   "module TerminalHome not found" 处失败——这是预期行为，用来尽早暴露
#   依赖缺失，而不是静默跳过。
#
# Termux
#   为什么需要：终端环境本体。APK 是上游官方发布的预签名 debug APK，二进制
#   不入库（见 .gitignore 与 prebuilt/README.md），因此构建前必须先执行
#   scripts/fetch-termux.sh 下载并校验 SHA256/大小。模块定义见本仓库
#   Android.bp（android_app_import，presigned）。
#   验证状态：版本 / URL / SHA256 / 大小已与上游发布资产核对（见
#   prebuilt/Termux.apk.sha256）；"作为系统预置应用在 Android 16 上运行"
#   未验证。
#
# 说明（产品契约）：
#   - Termux 由本仓库 Android.bp 用 android_app_import + presigned: true 预置，
#     APK 是 Termux 官方 GitHub Actions 的 Debug 签名——**绝不能重新签名**，
#     否则 SHA256 校验链失效，并影响与官方 Termux 插件的签名兼容性。
#   - 本仓库只负责"产品片段"（增加预置应用/overlay/只读属性），不修改、不删除
#     任何系统组件；SystemUI、Settings、launcher 等仍完全由上游 product 配置
#     （common_full_phone.mk / common_mobile.mk）提供。
#
# 关于默认桌面（HOME）/ 启动器（重要）：
#   上游 LineageOS 23.2 的默认启动器是 Launcher3QuickStep（定义在
#   vendor/lineage/config/common_mobile.mk；另有 Launcher3QuickStepGo /
#   Launcher3Overlay 变体）。**本片段不删除、不过滤、不替换任何启动器**，
#   也不使用 PRODUCT_PACKAGES 的移除技巧。
#   默认 HOME 的接管方案是：由 TerminalHome 以 Device Owner 身份调用
#   DevicePolicyManager.addPersistentPreferredActivity 把自己设为默认 HOME
#   （Phase 2 实现，未验证）。这是运行时策略，不应写进产品 makefile——
#   在产品配置层删启动器会与上游 common_mobile.mk 的组件清单维护冲突。
PRODUCT_PACKAGES += \
    TerminalHome \
    Termux

# ---------------------------------------------------------------------------
# 静态 overlay
# ---------------------------------------------------------------------------
# 为什么需要：目前只覆盖 frameworks/base 的个别 config 资源（当前仅
#   overlay/frameworks/base/core/res/res/values/config.xml 里的
#   config_showNavigationBar），用 PRODUCT_PACKAGE_OVERLAYS 的编译期静态
#   overlay 即可，不引入运行时 RRO 的额外安装/签名步骤。
# 验证状态：未构建、未实机验证。overlay 目录结构必须与目标包路径严格一致
#   （frameworks/base/core/res/res/...），否则资源不会生效；改动后需要
#   重新构建 system 镜像才可见。
PRODUCT_PACKAGE_OVERLAYS += \
    vendor/terminalos/overlay

# ---------------------------------------------------------------------------
# 只读产品标识
# ---------------------------------------------------------------------------
# 为什么需要：给 ROM 自身和后续的 TerminalHome / 初始化脚本一个可读的构建
#   来源标识，方便报障时确认版本。全部是 ro.*（property service 启动后只读），
#   不是运行时功能开关；这里刻意不放任何未经测试的功能开关类属性。
# 验证状态：属性名由本仓库新定义（上游 LineageOS 不存在同名属性），目前没有
#   任何组件读取它们；未实机验证。
PRODUCT_PROPERTY_OVERRIDES += \
    ro.terminalos.version=0.1.0-scaffold \
    ro.terminalos.branch=terminalos/lineage-23.2
