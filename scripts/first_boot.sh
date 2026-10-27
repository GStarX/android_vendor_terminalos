#!/bin/sh
#
# first_boot.sh —— TerminalOS 首次启动初始化【参考实现，未接入系统】
#
# ==========================================================================
# 状态与警告（必读）
# ==========================================================================
# 1) 本脚本**没有被任何 init.rc / service / 开机广播 / 系统属性触发**，
#    不会自动执行，不随 ROM 生效。它只是 Phase 2 设计评审用的参考实现。
# 2) 接入任何开机流程之前必须完成设计评审，至少覆盖：
#    - 启动时机：/data 是否已挂载、是否已解密（userdata 加密时尤其关键）；
#    - SELinux：读写 /data/local/terminalos 需要合适的 file context 与策略，
#      未处理时会被 avc denied，不能指望脚本自己解决；
#    - 失败处理：本脚本的所有失败都降级为 stderr/日志并 exit 0，绝不允许
#      阻塞开机；接入时也要保留这个约束；
#    - 幂等：以标记文件为准，多次执行不得产生额外副作用；
#    - 安全评审：本脚本**只做无害操作**（建目录、写自己的日志）；
#      任何 Termux bootstrap 安装、网络下载、包安装、权限授予都不属于
#      "无害初始化"，不能塞进 first_boot。那部分属于 Phase 2 之后的独立设计。
# 3) 脚本按 POSIX sh 编写（Android 的 /system/bin/sh 是 mksh），没有使用
#    bash 专属语法；这样将来若真要接入 init 不必先移植 shell。
#    但当前它只在仓库里作为参考，未在设备上执行过。
#
# ==========================================================================
# 行为（全部无害）
# ==========================================================================
#   - 以 root（uid 0）运行时才继续；否则安静退出 0。
#   - 标记文件 /data/local/terminalos/first_boot.done 存在 → 直接退出 0
#     （幂等：不重复写日志、不做任何其他操作）。
#   - 创建 /data/local/terminalos 与 /data/local/terminalos/logs 目录。
#   - 往 /data/local/terminalos/logs/first_boot.log 追加一条启动记录。
#   - 最后以"临时文件 + rename"写入标记文件；标记没写成功时保持未初始化状态，
#     下次启动可以重试（不会留下半成品标记）。
#   - 任何一步失败：写 stderr，脚本始终 exit 0（不得阻塞开机）。
#
# ==========================================================================
# 不做什么
# ==========================================================================
#   - 不安装/更新 Termux bootstrap，不写 Termux 的数据目录；
#   - 不联网、不调用包管理器（pm/am/cmd）、不修改系统属性；
#   - 不创建除 /data/local/terminalos 之外的任何路径；
#   - 不删除任何文件（除了自己写失败后留下的 .tmp 临时文件）。

set -u

BASE_DIR="/data/local/terminalos"
MARKER_FILE="${BASE_DIR}/first_boot.done"
LOG_DIR="${BASE_DIR}/logs"
LOG_FILE="${LOG_DIR}/first_boot.log"
TAG="terminalos-first-boot"
SCRIPT_VERSION="0.1.0-scaffold"

now_utc() {
    date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || printf 'unknown-time'
}

warn() {
    printf '%s: %s\n' "${TAG}" "$*" >&2
}

# 追加日志；写失败也不影响流程（例如目录刚创建时竞态、空间不足等）
log_line() {
    printf '%s %s %s\n' "$(now_utc)" "${TAG}" "$*" >>"${LOG_FILE}" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# 0. 只允许 root 执行。init 触发的脚本通常已是 root；在 host 上手工试跑时
#    会走这里，安静退出，不产生副作用。
# ---------------------------------------------------------------------------
current_uid="$(id -u 2>/dev/null || printf '1')"
if [ "${current_uid}" != "0" ]; then
    warn "not running as root (uid=${current_uid}); nothing to do"
    exit 0
fi

# ---------------------------------------------------------------------------
# 1. 幂等检查：标记文件存在即认为已初始化
# ---------------------------------------------------------------------------
if [ -e "${MARKER_FILE}" ]; then
    warn "already initialized (${MARKER_FILE}); skipping"
    exit 0
fi

# ---------------------------------------------------------------------------
# 2. 创建自己的目录；失败则放弃本次初始化（不阻塞开机）
# ---------------------------------------------------------------------------
if ! mkdir -p "${LOG_DIR}" 2>/dev/null; then
    warn "cannot create ${LOG_DIR}; skip first-boot init (boot must not be blocked)"
    exit 0
fi

# ---------------------------------------------------------------------------
# 3. 记录启动信息（只写日志，不做别的）
# ---------------------------------------------------------------------------
kernel_release="$(uname -r 2>/dev/null || true)"
[ -n "${kernel_release}" ] || kernel_release="unknown"

rom_version="$(getprop ro.terminalos.version 2>/dev/null || true)"
[ -n "${rom_version}" ] || rom_version="unknown"

android_release="$(getprop ro.build.version.release 2>/dev/null || true)"
[ -n "${android_release}" ] || android_release="unknown"

log_line "start script_version=${SCRIPT_VERSION} kernel=${kernel_release} rom=${rom_version} android=${android_release}"

# ---------------------------------------------------------------------------
# 4. 写标记文件（临时文件 + rename，避免半成品标记）
# ---------------------------------------------------------------------------
tmp_marker="${MARKER_FILE}.tmp"

if printf 'terminalos first_boot\nscript_version=%s\ncompleted_at=%s\n' \
    "${SCRIPT_VERSION}" "$(now_utc)" >"${tmp_marker}" 2>/dev/null; then
    if mv -f "${tmp_marker}" "${MARKER_FILE}" 2>/dev/null; then
        log_line "done marker=${MARKER_FILE}"
    else
        rm -f "${tmp_marker}" 2>/dev/null || true
        warn "cannot rename marker into place; will retry next boot"
    fi
else
    rm -f "${tmp_marker}" 2>/dev/null || true
    warn "cannot write marker; will retry next boot"
fi

# 无论上面发生什么，都不阻塞开机
exit 0
