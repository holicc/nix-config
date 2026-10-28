#!/usr/bin/env bash
# NixOS 配置维护脚本：把常用命令和"本地 input 覆盖参数"封装起来，不用每次敲一长串。
#
# 为什么需要 --override-input：
#   这台机器访问 GitHub 很慢，nixpkgs 和 noctalia 的源码是预先下载到 ~/nix-inputs/ 的本地副本，
#   构建时用 --override-input 指向它们，避免联网下载。flake.lock 里没有记录这两个本地路径，
#   所以每条 nix / nixos-rebuild 命令都要带上这些参数，本脚本会自动带上。
#
# 用法：./scripts/nixos.sh <命令>，不带参数或 help 查看全部命令。
# 需要 sudo 的命令（switch/test/boot/gc）会提示输入密码，脚本不会也不能代输。

set -euo pipefail

# ---- 可通过环境变量覆盖的设置 ----
HOST="${NIXOS_HOST:-nixos-dev}"                 # flake 里的 nixosConfigurations 名称
USER_NAME="${NIXOS_USER:-joe}"                  # home-manager 管理的用户
INPUTS_DIR="${NIX_INPUTS_DIR:-$HOME/nix-inputs}" # 本地 input 副本所在目录

# 脚本所在仓库的根目录（不管从哪里调用都能工作）
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_DIR"

# 所有 nix 命令共用的覆盖参数
OVERRIDES=(
  --override-input nixpkgs "path:${INPUTS_DIR}/nixpkgs"
  --override-input noctalia "git+file://${INPUTS_DIR}/noctalia"
  --no-write-lock-file
)

TOPLEVEL=".#nixosConfigurations.${HOST}.config.system.build.toplevel"

say() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31m错误：\033[0m%s\n' "$*" >&2; exit 1; }

# 本地 input 副本必须存在，否则给出明确提示而不是让 nix 报一堆难懂的错
need_inputs() {
  [ -d "${INPUTS_DIR}/nixpkgs" ] || die "找不到 ${INPUTS_DIR}/nixpkgs（nixpkgs 源码副本）"
  [ -d "${INPUTS_DIR}/noctalia/.git" ] \
    || die "找不到 ${INPUTS_DIR}/noctalia，或它不是 git 仓库（Noctalia 的 flake 需要 git 版本号）"
}

# flake 只认 git 已 track 的文件，新增文件后必须 git add，否则会报"文件不存在"
stage() {
  git add -A
}

# 构建但不切换，只输出构建结果的 store 路径（不在仓库里留下 result 链接）
build_path() {
  nix build "$TOPLEVEL" --no-link --print-out-paths "${OVERRIDES[@]}"
}

# 校验：求值系统配置 + 用 niri 校验生成的 config.kdl（不构建，几十秒内完成）
cmd_check() {
  need_inputs
  stage
  say "求值系统配置（语法、选项、引用是否正确）"
  nix eval --raw "${TOPLEVEL}.drvPath" "${OVERRIDES[@]}" >/dev/null
  echo "系统配置求值通过"

  say "校验生成的 Niri 配置"
  local tmp
  tmp="$(mktemp --suffix=.kdl)"
  trap 'rm -f "$tmp"' RETURN
  nix eval --raw ".#nixosConfigurations.${HOST}.config.home-manager.users.${USER_NAME}.xdg.configFile.\"niri/config.kdl\".text" \
    "${OVERRIDES[@]}" > "$tmp"
  niri validate -c "$tmp"
}

cmd_build() {
  need_inputs; stage
  say "构建（不切换系统）"
  build_path
}

# 对比当前运行的系统和新构建的系统：只列出软件包的增删和版本变化，没有输出说明包没变
cmd_diff() {
  need_inputs; stage
  say "构建新配置"
  local new
  new="$(build_path)"
  say "与当前系统对比（无输出 = 软件包完全一致）"
  nix store diff-closures /run/current-system "$new"
}

# switch/test/boot 共用：先校验再交给 nixos-rebuild
rebuild() {
  local action="$1"
  need_inputs; stage
  say "先校验配置"
  cmd_check
  say "sudo nixos-rebuild ${action}"
  sudo nixos-rebuild "$action" --flake ".#${HOST}" "${OVERRIDES[@]}"
}

cmd_gens() { nixos-rebuild list-generations; }

# 已安装软件：系统级、用户级，字体
cmd_pkgs() {
  local strip='s|/nix/store/[a-z0-9]*-||'
  say "系统级软件包（含服务模块带入的）"
  nix-store -q --references /run/current-system/sw | sed "$strip" | sort -u
  say "${USER_NAME} 用户级软件包（home-manager）"
  nix-store -q --references "/etc/profiles/per-user/${USER_NAME}" | sed "$strip" | sort -u
  say "字体"
  fc-list : family | sort -u
}

# 清理 7 天前的旧系统版本（之后无法回滚到更早的版本）
cmd_gc() {
  say "清理系统 profile 和用户 profile 中 7 天前的版本"
  sudo nix-collect-garbage --delete-older-than 7d
  nix-collect-garbage --delete-older-than 7d
}

# 一屏看清当前状态
cmd_status() {
  say "内核与系统版本"
  uname -r
  readlink /run/current-system
  say "本地 input 副本"
  for d in nixpkgs noctalia; do
    if [ -d "${INPUTS_DIR}/${d}" ]; then echo "  ${d}: 存在"; else echo "  ${d}: 缺失！"; fi
  done
  if [ -d "${INPUTS_DIR}/noctalia/.git" ]; then
    echo "  noctalia 提交: $(git -C "${INPUTS_DIR}/noctalia" log --oneline -1)"
  fi
  say "仓库状态"
  git status --short | sed 's/^/  /' || true
  say "关键服务"
  for s in greetd tlp bluetooth NetworkManager upower; do
    printf '  %-16s %s\n' "$s" "$(systemctl is-active "$s" 2>/dev/null || true)"
  done
}

usage() {
  cat <<EOF
用法：$(basename "$0") <命令>

  check     只校验：求值系统配置 + 用 niri 校验生成的 KDL（不构建，不需要 sudo）
  build     构建但不切换，输出结果路径
  diff      构建并与当前系统对比软件包差异（无输出 = 包没变）
  test      校验后立即切换，但不写入开机项，重启后回到旧配置（需要 sudo）
  boot      校验后设为下次开机使用，不立即切换（需要 sudo）
  switch    校验后构建并立即切换，下次开机也用它（需要 sudo）
  gens      列出所有系统版本（可回滚）
  pkgs      列出已安装的软件包和字体
  gc        清理 7 天前的旧版本（需要 sudo）
  status    内核、系统版本、本地 input、仓库状态、关键服务
  help      显示本说明

环境变量（可选）：NIXOS_HOST=${HOST}  NIXOS_USER=${USER_NAME}  NIX_INPUTS_DIR=${INPUTS_DIR}
EOF
}

case "${1:-help}" in
  check)  cmd_check ;;
  build)  cmd_build ;;
  diff)   cmd_diff ;;
  test)   rebuild test ;;
  boot)   rebuild boot ;;
  switch) rebuild switch ;;
  gens)   cmd_gens ;;
  pkgs)   cmd_pkgs ;;
  gc)     cmd_gc ;;
  status) cmd_status ;;
  help|-h|--help) usage ;;
  *) usage; exit 1 ;;
esac
