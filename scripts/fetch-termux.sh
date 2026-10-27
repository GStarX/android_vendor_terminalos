#!/usr/bin/env bash
#
# fetch-termux.sh —— 下载并校验 TerminalOS 预置的 Termux APK
#
# 用途：
#   从 Termux 官方 GitHub release 下载锁定的 arm64-v8a APK，写入
#   prebuilt/Termux.apk，并做"大小 + SHA256"双重校验。APK 不入库
#   （见 .gitignore / prebuilt/README.md），因此**构建前必须执行本脚本**。
#
# 用法（在任意目录均可执行，脚本按自身位置定位仓库根目录）：
#   bash scripts/fetch-termux.sh            # 幂等：已存在且校验通过则直接跳过
#   bash scripts/fetch-termux.sh --force    # 忽略已有文件，强制重新下载
#   bash scripts/fetch-termux.sh --help
#
# 行为与约束：
#   - set -euo pipefail，任何一步失败都以非零状态退出；
#   - 下载先写到 *.apk.part，校验通过后才 rename 为 Termux.apk（不会留下损坏文件
#     覆盖旧文件）；
#   - 校验脚本内硬编码的 SHA256 与 prebuilt/Termux.apk.sha256 完全一致，
#     防止只改一处造成版本漂移；不一致直接失败；
#   - 校验目标文件大小必须等于 TERMUX_SIZE_BYTES（截断下载可被立刻发现）；
#   - 成功后打印 prebuilt/Termux.apk 的绝对路径。
#
# 不做什么：
#   - 不重新签名、不修改 APK 内容（官方 debug 签名，Android.bp 用 presigned）；
#   - 不调用 git（二进制不入库，由 .gitignore 保证）；
#   - 不从第三方镜像下载，只使用下面 TERMUX_URL 指向的官方 release 资产。
#
# 依赖：bash、curl 或 wget、sha256sum 或 shasum、awk、wc。
# 状态：脚本逻辑已静态审查；因为当前没有 Linux 构建机，本脚本尚未在目标构建
#       环境中实际运行过。APK 版本/SHA256/大小已与上游发布资产核对。
#
# 升级版本时：同步修改下面四个常量 + prebuilt/Termux.apk.sha256 + 本仓库
# prebuilt/README.md 的版本历史（步骤见 prebuilt/README.md）。

set -euo pipefail

# ---------------------------------------------------------------------------
# 锁定的 Termux 版本（升级时四处一起改）
# ---------------------------------------------------------------------------
TERMUX_VERSION="0.118.3"
TERMUX_URL="https://github.com/termux/termux-app/releases/download/v${TERMUX_VERSION}/termux-app_v${TERMUX_VERSION}%2Bgithub-debug_arm64-v8a.apk"
TERMUX_SHA256="72fdb596045116bf5ba1b5bdf5b26fddb9acc0bd074ad9f2da9eb0ae85e83a4e"
TERMUX_SIZE_BYTES="35106607"
APK_NAME="Termux.apk"

# ---------------------------------------------------------------------------
# 路径解析：以脚本所在位置推导仓库根目录，不依赖当前工作目录
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." >/dev/null 2>&1 && pwd)"
PREBUILT_DIR="${REPO_ROOT}/prebuilt"
APK_PATH="${PREBUILT_DIR}/${APK_NAME}"
SHA256_FILE="${PREBUILT_DIR}/${APK_NAME}.sha256"
TMP_PATH="${APK_PATH}.part"

log() { printf '[fetch-termux] %s\n' "$*"; }

die() {
    printf '[fetch-termux] ERROR: %s\n' "$*" >&2
    exit 1
}

cleanup() {
    if [ -f "${TMP_PATH}" ]; then
        rm -f "${TMP_PATH}"
    fi
}
trap cleanup EXIT

usage() {
    cat <<'EOF'
用法: bash scripts/fetch-termux.sh [--force]

  （无参数）   已存在且大小/SHA256 校验通过则跳过；否则下载并校验
  --force      忽略已有 APK，强制重新下载
  -h, --help   显示本帮助
EOF
}

# ---------------------------------------------------------------------------
# 基础工具
# ---------------------------------------------------------------------------
file_size_bytes() {
    wc -c < "$1" | tr -d '[:space:]'
}

file_sha256() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$1" | awk '{print $1}'
    else
        die "找不到 sha256sum 或 shasum，无法校验 SHA256"
    fi
}

# 校验 APK：文件存在 + 大小正确 + SHA256 正确。成功返回 0，失败返回 1。
verify_apk() {
    local path="$1"
    local actual_size actual_sha

    if [ ! -f "${path}" ]; then
        return 1
    fi

    actual_size="$(file_size_bytes "${path}")"
    if [ "${actual_size}" != "${TERMUX_SIZE_BYTES}" ]; then
        log "大小不匹配: 期望 ${TERMUX_SIZE_BYTES} 字节，实际 ${actual_size} 字节（${path}）"
        return 1
    fi

    actual_sha="$(file_sha256 "${path}")"
    if [ "${actual_sha}" != "${TERMUX_SHA256}" ]; then
        log "SHA256 不匹配: 期望 ${TERMUX_SHA256}，实际 ${actual_sha}（${path}）"
        return 1
    fi

    return 0
}

# ---------------------------------------------------------------------------
# 一致性检查：prebuilt/Termux.apk.sha256 必须与脚本内硬编码哈希一致
# ---------------------------------------------------------------------------
check_pinned_hash_file() {
    local line expected_sha file_name

    if [ ! -f "${SHA256_FILE}" ]; then
        die "缺少校验文件: ${SHA256_FILE}（应形如 \"<sha256>  ${APK_NAME}\"）"
    fi

    line="$(head -n 1 "${SHA256_FILE}" | tr -d '\r')"
    expected_sha="$(printf '%s\n' "${line}" | awk '{print $1}')"
    file_name="$(printf '%s\n' "${line}" | awk '{print $2}')"

    if [ -z "${expected_sha}" ]; then
        die "校验文件为空或格式错误: ${SHA256_FILE}"
    fi
    if [ "${expected_sha}" != "${TERMUX_SHA256}" ]; then
        die "SHA256 不一致：脚本内=${TERMUX_SHA256} 文件内=${expected_sha}（升级版本时必须同时更新两处 + 本文件）"
    fi
    if [ -n "${file_name}" ] && [ "${file_name}" != "${APK_NAME}" ]; then
        die "校验文件里的文件名不是 ${APK_NAME}: ${file_name}"
    fi

    log "校验文件一致: v${TERMUX_VERSION} / sha256 ${TERMUX_SHA256:0:16}... / ${TERMUX_SIZE_BYTES} 字节"
}

# ---------------------------------------------------------------------------
# 下载（curl 优先，wget 兜底）；先写临时文件，校验通过后原子替换
# ---------------------------------------------------------------------------
download_apk() {
    log "开始下载 Termux v${TERMUX_VERSION}（${TERMUX_SIZE_BYTES} 字节）..."
    log "URL: ${TERMUX_URL}"

    rm -f "${TMP_PATH}"

    if command -v curl >/dev/null 2>&1; then
        if ! curl --fail --location --retry 3 --retry-delay 2 --connect-timeout 30 \
            --output "${TMP_PATH}" "${TERMUX_URL}"; then
            die "curl 下载失败（网络/资产变更/代理问题）: ${TERMUX_URL}"
        fi
    elif command -v wget >/dev/null 2>&1; then
        if ! wget --tries=3 --timeout=30 --output-document="${TMP_PATH}" "${TERMUX_URL}"; then
            die "wget 下载失败（网络/资产变更/代理问题）: ${TERMUX_URL}"
        fi
    else
        die "找不到 curl 或 wget，无法下载"
    fi

    if ! verify_apk "${TMP_PATH}"; then
        die "下载文件校验失败，已丢弃临时文件：${TMP_PATH}"
    fi

    mv -f "${TMP_PATH}" "${APK_PATH}"
    log "下载完成并已通过校验"
}

# ---------------------------------------------------------------------------
# 主流程
# ---------------------------------------------------------------------------
main() {
    local force=0

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --force)
                force=1
                shift
                ;;
            -h|--help)
                usage
                return 0
                ;;
            *)
                die "未知参数: $1（可用: --force, --help）"
                ;;
        esac
    done

    log "TerminalOS Termux fetcher（锁定版本 v${TERMUX_VERSION}）"
    log "仓库根目录: ${REPO_ROOT}"

    mkdir -p "${PREBUILT_DIR}"
    check_pinned_hash_file

    if [ "${force}" -eq 0 ] && verify_apk "${APK_PATH}"; then
        log "已存在且校验通过，跳过下载（幂等）"
        printf '%s\n' "${APK_PATH}"
        return 0
    fi

    if [ "${force}" -eq 1 ]; then
        log "指定 --force，强制重新下载"
    elif [ -f "${APK_PATH}" ]; then
        log "已有 APK 校验失败，将重新下载并覆盖"
    else
        log "未找到 ${APK_PATH}，开始下载"
    fi

    download_apk

    log "校验通过：大小 ${TERMUX_SIZE_BYTES} 字节，SHA256 ${TERMUX_SHA256}"
    printf '%s\n' "${APK_PATH}"
}

main "$@"
