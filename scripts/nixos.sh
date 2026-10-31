#!/usr/bin/env bash
# NixOS 配置维护脚本：把常用命令封装起来，不用每次敲一长串。
#
# 用法：nx <命令>（home/default.nix 装的包装命令）或 ./scripts/nixos.sh <命令>；
#       不带参数或 help 查看全部命令。
# 需要 sudo 的命令（switch/test/boot/gc）会提示输入密码，脚本不会也不能代输。
#
# 结构：这个文件只做命令登记和分发；具体实现按职责放在 lib/ 下：
#   lib/common.sh   输出函数、flake 取值、git 暂存
#   lib/system.sh   check / build / diff / switch / update / gc / status 等系统命令（cmd_<名字>）
#   lib/proxy.sh    nx proxy 的全部子命令（pcmd_<名字>）
# 加一个命令：在对应文件里写 cmd_<名字> 函数，再在下面的 COMMANDS 表里登记一行（名字|说明）。
# 脚本的运行输出统一用英文 + emoji，注释保持中文。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# 仓库根目录：不管从哪里调用都在仓库里执行（flake、git 命令都依赖它）
cd "$SCRIPT_DIR/.."

# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/system.sh
source "$SCRIPT_DIR/lib/system.sh"
# shellcheck source=lib/proxy.sh
source "$SCRIPT_DIR/lib/proxy.sh"

# 命令表："名字|说明"。主帮助从这里生成，分发时找同名的 cmd_<名字> 函数
COMMANDS=(
  "check|Validate only: evaluate the system config + validate generated Niri KDL (no build, no sudo)"
  "build|Build without switching, print the result path"
  "diff|Build and compare packages with the running system (no output = identical)"
  "test|Check, then activate now without a boot entry; reverts on reboot (sudo)"
  "boot|Check, then use on next boot without activating now (sudo)"
  "switch|Check, build and activate now; also used on next boot (sudo)"
  "update|Update flake inputs into flake.lock (all except neomacs; "update --all" includes neomacs; or name inputs: update nixpkgs, update neomacs); "update qingjian" also moves to the latest release; no build or switch, preview with: diff"
  "gens|List all system generations (rollback targets)"
  "pkgs|List installed packages and fonts"
  "gc|Keep only the newest ${KEEP_GENERATIONS} system generations and reclaim space (sudo)"
  "status|Kernel, generation, repo state, key services"
  "proxy|Proxy (mihomo / Clash core), subcommands (details: proxy help):"
  "help|Show this help (also: -h, --help; works after any command, e.g. \"proxy --help\")"
)

cmd_help() { usage; }

usage() {
  local entry name
  echo "Usage: ${PROG} <command>"
  echo
  for entry in "${COMMANDS[@]}"; do
    name="${entry%%|*}"
    printf '  %-9s %s\n' "$name" "${entry#*|}"
    if [ "$name" = proxy ]; then proxy_usage_lines; fi
  done
  echo
  echo "Environment (optional): NIXOS_HOST=${HOST}  NIXOS_USER=${USER_NAME}"
}

main() {
  local cmd="${1:-help}"

  # 任何命令后面带 -h / --help 都只显示帮助，不去执行（例如 `nx switch --help` 不会真的切换系统）
  if [ "${2:-}" = "-h" ] || [ "${2:-}" = "--help" ]; then
    case "$cmd" in proxy) proxy_help ;; *) usage ;; esac
    return 0
  fi

  case "$cmd" in -h|--help) cmd=help ;; esac
  shift || true

  if declare -F "cmd_${cmd}" >/dev/null; then
    "cmd_${cmd}" "$@"
  else
    usage
    exit 1
  fi
}

main "$@"
