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

# ---- 代理（mihomo，即 Clash 内核）----
# 订阅地址属于敏感信息，配置放在仓库外的 PROXY_CONF，脚本只负责复制模板、启停、切换 TUN。
PROXY_CONF="${MIHOMO_CONF:-$HOME/.config/mihomo/config.yaml}"
PROXY_PORT="${MIHOMO_PORT:-7890}"
PROXY_API="${MIHOMO_API:-127.0.0.1:9090}"

cmd_proxy() {
  local sub="${1:-status}"
  shift || true
  case "$sub" in
    init)
      # 复制模板到仓库外并收紧权限；已存在则不覆盖，避免丢掉你填好的订阅
      if [ -e "$PROXY_CONF" ]; then
        echo "已存在：$PROXY_CONF（不覆盖）"
      else
        mkdir -p "$(dirname "$PROXY_CONF")"
        cp examples/mihomo/config.example.yaml "$PROXY_CONF"
        chmod 600 "$PROXY_CONF"
        say "已创建 $PROXY_CONF"
      fi
      echo "下一步：编辑它，把 proxy-providers.sub.url 换成你的订阅地址（不要提交到 git）"
      ;;
    on)
      [ -f "$PROXY_CONF" ] || die "没有配置文件，先运行：$0 proxy init，并填入订阅地址"
      grep -q "在这里填订阅地址" "$PROXY_CONF" && die "配置里还是占位符，请先在 $PROXY_CONF 填入订阅地址"
      sudo systemctl start mihomo
      echo "mihomo 已启动，本机代理：http://127.0.0.1:${PROXY_PORT}"
      echo "让命令走代理：$0 proxy run <命令>，例如 $0 proxy run git push"
      ;;
    off)
      sudo systemctl stop mihomo
      echo "mihomo 已停止"
      ;;
    status)
      printf 'mihomo 服务：%s\n' "$(systemctl is-active mihomo 2>/dev/null || true)"
      if [ -f "$PROXY_CONF" ]; then echo "配置文件：$PROXY_CONF"; else echo "配置文件：缺失（先 proxy init）"; fi
      if systemctl is-active --quiet mihomo; then
        printf 'TUN 透明代理：'
        curl -s "http://${PROXY_API}/configs" | grep -o '"tun":{"enable":[a-z]*' | grep -o '[a-z]*$' || echo "读取失败"
      fi
      ;;
    tun)
      # 运行时切换透明代理，不需要重新构建；需要 mihomo 已启动
      local state="${1:-}"
      case "$state" in on) state=true ;; off) state=false ;; *) die "用法：$0 proxy tun on|off" ;; esac
      curl -sf -X PATCH "http://${PROXY_API}/configs" -H 'Content-Type: application/json' \
        -d "{\"tun\":{\"enable\":${state}}}" || die "切换失败：mihomo 是否已启动（proxy on）？"
      echo "TUN 已设为 ${state}"
      ;;
    run)
      # 让一条命令走代理，例如：proxy run git push / proxy run nix flake show
      [ "$#" -gt 0 ] || die "用法：$0 proxy run <命令>"
      systemctl is-active --quiet mihomo || die "mihomo 没有运行，先：$0 proxy on"
      https_proxy="http://127.0.0.1:${PROXY_PORT}" http_proxy="http://127.0.0.1:${PROXY_PORT}" \
      HTTPS_PROXY="http://127.0.0.1:${PROXY_PORT}" HTTP_PROXY="http://127.0.0.1:${PROXY_PORT}" "$@"
      ;;
    *) die "未知的 proxy 子命令：$sub（init|on|off|status|tun|run）" ;;
  esac
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
  proxy     代理（mihomo / Clash 内核），子命令：
              init          复制配置模板到 ~/.config/mihomo/config.yaml，之后自己填订阅地址
              on | off      启动 / 停止服务（需要 sudo；默认不随开机启动，省电）
              status        服务状态和 TUN 是否开启
              tun on|off    运行时切换透明代理（TUN），不用重新构建
              run <命令>    让一条命令走代理，例如：proxy run git push
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
  proxy)  shift; cmd_proxy "$@" ;;
  help|-h|--help) usage ;;
  *) usage; exit 1 ;;
esac
