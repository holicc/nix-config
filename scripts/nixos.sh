#!/usr/bin/env bash
# NixOS 配置维护脚本：把常用命令和"本地 input 覆盖参数"封装起来，不用每次敲一长串。
#
# 为什么需要 --override-input：
#   这台机器访问 GitHub 很慢，nixpkgs 和 noctalia 的源码是预先下载到 ~/nix-inputs/ 的本地副本，
#   构建时用 --override-input 指向它们，避免联网下载。flake.lock 里没有记录这两个本地路径，
#   所以每条 nix / nixos-rebuild 命令都要带上这些参数，本脚本会自动带上。
#
# 用法：nx <命令>（home/default.nix 装的包装命令）或 ./scripts/nixos.sh <命令>；
#       不带参数或 help 查看全部命令。
# 需要 sudo 的命令（switch/test/boot/gc）会提示输入密码，脚本不会也不能代输。
# 注意：脚本的运行输出统一用英文 + emoji（成功 ✅、步骤 🔹、警告 ⚠️、错误 ❌），注释保持中文。

set -euo pipefail

# ---- 可通过环境变量覆盖的设置 ----
HOST="${NIXOS_HOST:-nixos-dev}"                  # flake 里的 nixosConfigurations 名称
USER_NAME="${NIXOS_USER:-joe}"                   # home-manager 管理的用户
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

# ---- 输出辅助函数 ----
say()  { printf '\033[1;34m🔹 %s\033[0m\n' "$*"; }
ok()   { printf '\033[1;32m✅ %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m⚠️  %s\033[0m\n' "$*"; }
die()  { printf '\033[1;31m❌ Error: %s\033[0m\n' "$*" >&2; exit 1; }

# 过滤 nix 的 "not writing modified lock file" 警告块：因为我们用了 --override-input 和
# --no-write-lock-file，每条 nix 命令都会打印这一大段（含 Updated/Added input 的列表），
# 淹没真正有用的输出。只去掉这一段，其他警告和错误原样保留。
lock_filter() {
  awk '
    /^warning: not writing modified lock file/ { skip = 1; next }
    skip && /^([•]|[[:space:]])/               { next }
    { skip = 0; print }
  '
}

# 本地 input 副本必须存在，否则给出明确提示而不是让 nix 报一堆难懂的错
need_inputs() {
  [ -d "${INPUTS_DIR}/nixpkgs" ] || die "cannot find ${INPUTS_DIR}/nixpkgs (local nixpkgs source copy)"
  [ -d "${INPUTS_DIR}/noctalia/.git" ] \
    || die "cannot find ${INPUTS_DIR}/noctalia, or it is not a git repository (Noctalia's flake needs a git revision)"
}

# flake 只认 git 已 track 的文件，新增文件后必须 git add，否则会报"文件不存在"
stage() {
  git add -A
}

# 构建但不切换，只输出构建结果的 store 路径（不在仓库里留下 result 链接）
build_path() {
  nix build "$TOPLEVEL" --no-link --print-out-paths "${OVERRIDES[@]}" 2> >(lock_filter >&2)
}

# 校验：求值系统配置 + 用 niri 校验生成的 config.kdl（不构建，几十秒内完成）
cmd_check() {
  need_inputs
  stage
  say "Evaluating system configuration (syntax, options, references)"
  nix eval --raw "${TOPLEVEL}.drvPath" "${OVERRIDES[@]}" >/dev/null 2> >(lock_filter >&2)
  ok "System configuration evaluates"

  say "Validating generated Niri config"
  # 不用 trap 清理临时文件：RETURN trap 是全局的，函数返回后依然有效，
  # 会在别的函数返回时再次触发，那时局部变量已不存在（set -u 下会报 unbound variable）
  local tmp niri_ok=1
  tmp="$(mktemp --suffix=.kdl)"
  nix eval --raw ".#nixosConfigurations.${HOST}.config.home-manager.users.${USER_NAME}.xdg.configFile.\"niri/config.kdl\".text" \
    "${OVERRIDES[@]}" > "$tmp" 2> >(lock_filter >&2) || niri_ok=0
  if [ "$niri_ok" = 1 ] && niri validate -c "$tmp" 2>&1 | grep -v -E 'DEBUG.*niri_config'; then :; else niri_ok=0; fi
  rm -f "$tmp"
  [ "$niri_ok" = 1 ] || die "Niri config validation failed (see output above)"
  ok "Niri config is valid"
  ok "All checks passed 🎉"
}

cmd_build() {
  need_inputs; stage
  say "Building (no switch)"
  local path
  path="$(build_path)"
  ok "Build finished: ${path}"
}

# 对比当前运行的系统和新构建的系统：只列出软件包的增删和版本变化
cmd_diff() {
  need_inputs; stage
  say "Building new configuration"
  local new out
  new="$(build_path)"
  say "Comparing with the running system"
  out="$(nix store diff-closures /run/current-system "$new")"
  if [ -z "$out" ]; then
    ok "Packages are identical to the running system 🎉"
  else
    printf '%s\n' "$out"
    ok "Diff finished (see changes above)"
  fi
}

# switch/test/boot 共用：先校验再交给 nixos-rebuild
rebuild() {
  local action="$1"
  need_inputs; stage
  say "Checking configuration first"
  cmd_check
  say "Running: sudo nixos-rebuild ${action}"
  sudo nixos-rebuild "$action" --flake ".#${HOST}" "${OVERRIDES[@]}" 2> >(lock_filter >&2)
  ok "nixos-rebuild ${action} completed 🎉"
  if [ "$action" = "switch" ] || [ "$action" = "test" ]; then
    echo "   Tip: open a new shell (or run: hash -r) if a newly installed command is not found."
  fi
}

cmd_gens() { nixos-rebuild list-generations; }

# 已安装软件：系统级、用户级，字体
cmd_pkgs() {
  local strip='s|/nix/store/[a-z0-9]*-||'
  say "System packages (including those pulled in by service modules)"
  nix-store -q --references /run/current-system/sw | sed "$strip" | sort -u
  say "User packages for ${USER_NAME} (home-manager)"
  nix-store -q --references "/etc/profiles/per-user/${USER_NAME}" | sed "$strip" | sort -u
  say "Fonts"
  fc-list : family | sort -u
}

# 清理 7 天前的旧系统版本（之后无法回滚到更早的版本）
cmd_gc() {
  say "Removing generations older than 7 days (you cannot roll back to them afterwards)"
  sudo nix-collect-garbage --delete-older-than 7d
  nix-collect-garbage --delete-older-than 7d
  ok "Garbage collection done"
}

# 一屏看清当前状态
cmd_status() {
  say "Kernel and system generation"
  echo "   kernel: $(uname -r)"
  echo "   system: $(readlink /run/current-system)"

  say "Local inputs"
  for d in nixpkgs noctalia; do
    if [ -d "${INPUTS_DIR}/${d}" ]; then echo "   ✅ ${d}"; else echo "   ❌ ${d} (missing!)"; fi
  done
  if [ -d "${INPUTS_DIR}/noctalia/.git" ]; then
    echo "   noctalia commit: $(git -C "${INPUTS_DIR}/noctalia" log --oneline -1)"
  fi

  say "Repository"
  local changes
  changes="$(git status --short)"
  if [ -z "$changes" ]; then echo "   ✅ clean"; else printf '%s\n' "$changes" | sed 's/^/   /'; fi

  say "Key services"
  local s state
  for s in greetd tlp bluetooth NetworkManager upower mihomo; do
    state="$(systemctl is-active "$s" 2>/dev/null || true)"
    if [ "$state" = "active" ]; then
      printf '   ✅ %-16s %s\n' "$s" "$state"
    else
      printf '   ⚪ %-16s %s\n' "$s" "${state:-unknown}"
    fi
  done
}

# ---- 代理（mihomo，即 Clash 内核）----
# 订阅地址属于敏感信息，配置放在仓库外的 PROXY_CONF，脚本只负责复制模板、启停、切换 TUN。
PROXY_CONF="${MIHOMO_CONF:-$HOME/.config/mihomo/config.yaml}"
PROXY_PORT="${MIHOMO_PORT:-7890}"
PROXY_API="${MIHOMO_API:-127.0.0.1:9090}"
# 模板里订阅地址的占位符（模板是中文的，这里要和它保持一致，不属于脚本输出）
PROXY_PLACEHOLDER="在这里填订阅地址"

# 节点组名（模板 proxy-groups 里的组）。订阅里常混着几条展示用的假节点
# （官网、续费入口、剩余流量、到期时间），不是真节点，所以在列表里隐藏、也不允许按编号选中
PROXY_GROUP="${MIHOMO_GROUP:-PROXY}"
PROXY_INFO_RE='://|剩余|重置|到期|官网|续费|过滤'

# 通过 mihomo 的本地 API 读取节点组信息；不依赖 jq，用 grep/sed 解析 JSON
proxy_group_json() { curl -sf -m 8 "http://${PROXY_API}/proxies/${PROXY_GROUP}"; }
proxy_now() {
  proxy_group_json | grep -o '"now":"[^"]*"' | sed -e 's/^"now":"//' -e 's/"$//'
}
proxy_nodes() {
  proxy_group_json | grep -o '"all":\[[^]]*\]' \
    | sed -e 's/^"all":\["//' -e 's/"\]$//' -e 's/","/\n/g' | grep -v -E "$PROXY_INFO_RE"
}

cmd_proxy() {
  local sub="${1:-status}"
  shift || true
  case "$sub" in
    init)
      # 只需要输入订阅地址：配置文件不存在就先从模板复制，然后只替换其中的订阅地址那一行。
      # 地址用 read -s 读取：输入不回显，也不会进命令历史或进程参数列表
      if [ ! -e "$PROXY_CONF" ]; then
        mkdir -p "$(dirname "$PROXY_CONF")"
        cp examples/mihomo/config.example.yaml "$PROXY_CONF"
        ok "Created ${PROXY_CONF} from the template"
      fi
      local url esc
      read -r -s -p "Paste your subscription URL (input is hidden): " url
      echo
      case "$url" in http://*|https://*) ;; *) die "that does not look like an http(s) URL" ;; esac
      case "$url" in *'"'*|*[[:space:]]*) die "the URL must not contain spaces or double quotes" ;; esac
      # 转义 sed 替换串里的特殊字符（反斜杠、&、分隔符 |）
      esc="$(printf '%s' "$url" | sed -e 's/[\\&|]/\\&/g')"
      sed -i "s|^\(    url: \)\".*\"|\1\"${esc}\"|" "$PROXY_CONF"
      chmod 600 "$PROXY_CONF"
      ok "Subscription URL saved to ${PROXY_CONF} (mode 600, never commit it)"
      say "Next: $(basename "$0") proxy on"
      ;;
    on)
      [ -f "$PROXY_CONF" ] || die "no config file; run '$(basename "$0") proxy init' first and fill in your subscription URL"
      if grep -q "$PROXY_PLACEHOLDER" "$PROXY_CONF"; then
        die "config still contains the placeholder; put your subscription URL into ${PROXY_CONF}"
      fi
      sudo systemctl start mihomo
      ok "mihomo started 🚀"
      echo "   With TUN on (the default in the template) all traffic goes through the proxy; no per-command setup needed."
      echo "   A local HTTP/SOCKS proxy is also available at http://127.0.0.1:${PROXY_PORT}"
      echo "   If SSH or the LAN misbehaves: $(basename "$0") proxy tun off   or   $(basename "$0") proxy off"
      ;;
    off)
      sudo systemctl stop mihomo
      ok "mihomo stopped"
      ;;
    status)
      if systemctl is-active --quiet mihomo; then
        ok "mihomo service: active"
        echo "   node: $(proxy_now || echo unknown)"
        printf '   TUN: '
        curl -s "http://${PROXY_API}/configs" | grep -o '"tun":{"enable":[a-z]*' | grep -o '[a-z]*$' || echo "could not read"
      else
        warn "mihomo service: $(systemctl is-active mihomo 2>/dev/null || true)"
      fi
      if [ -f "$PROXY_CONF" ]; then echo "   config: ${PROXY_CONF}"; else echo "   config: missing (run proxy init)"; fi
      ;;
    tun)
      # 运行时切换透明代理，不需要重新构建；需要 mihomo 已启动
      local state="${1:-}"
      case "$state" in on) state=true ;; off) state=false ;; *) die "usage: $(basename "$0") proxy tun on|off" ;; esac
      curl -sf -X PATCH "http://${PROXY_API}/configs" -H 'Content-Type: application/json' \
        -d "{\"tun\":{\"enable\":${state}}}" || die "switching failed; is mihomo running? (proxy on)"
      ok "TUN set to ${state}"
      ;;
    nodes)
      # 列出节点，当前使用的打 ✅；编号可直接给 `proxy use`
      systemctl is-active --quiet mihomo || die "mihomo is not running; run '$(basename "$0") proxy on' first"
      local now i=0 n
      now="$(proxy_now || true)"
      say "Nodes in group ${PROXY_GROUP} (info-only entries from the subscription are hidden)"
      while IFS= read -r n; do
        i=$((i + 1))
        if [ "$n" = "$now" ]; then
          printf '   ✅ %3d  %s  (current)\n' "$i" "$n"
        else
          printf '      %3d  %s\n' "$i" "$n"
        fi
      done < <(proxy_nodes || true)
      [ "$i" -gt 0 ] || warn "no nodes found (subscription not loaded yet? check: journalctl -u mihomo -b)"
      echo "   Switch with: $(basename "$0") proxy use <number|name>"
      ;;
    use)
      # 切换节点：参数是 nodes 列表里的编号，或节点的完整名称。只改 mihomo 运行时选择，重启后可能恢复
      local want="${1:-}" name=""
      [ -n "$want" ] || die "usage: $(basename "$0") proxy use <number|name>"
      systemctl is-active --quiet mihomo || die "mihomo is not running; run '$(basename "$0") proxy on' first"
      if [[ "$want" =~ ^[0-9]+$ ]]; then
        name="$(proxy_nodes | sed -n "${want}p" || true)"
        [ -n "$name" ] || die "no node with number ${want}; run: $(basename "$0") proxy nodes"
      else
        name="$want"
      fi
      case "$name" in *'"'*|*'\'*) die "node name must not contain double quotes or backslashes" ;; esac
      curl -sf -m 8 -X PUT "http://${PROXY_API}/proxies/${PROXY_GROUP}" -H 'Content-Type: application/json' \
        -d "{\"name\":\"${name}\"}" >/dev/null \
        || die "switching failed; check the exact name with: $(basename "$0") proxy nodes"
      ok "Switched ${PROXY_GROUP} to: ${name}"
      ;;
    *) die "unknown proxy subcommand: ${sub} (init|on|off|status|tun|nodes|use)" ;;
  esac
}

usage() {
  cat <<EOF
Usage: $(basename "$0") <command>

  check     Validate only: evaluate the system config + validate generated Niri KDL (no build, no sudo)
  build     Build without switching, print the result path
  diff      Build and compare packages with the running system (no output = identical)
  test      Check, then activate now without a boot entry; reverts on reboot (sudo)
  boot      Check, then use on next boot without activating now (sudo)
  switch    Check, build and activate now; also used on next boot (sudo)
  gens      List all system generations (rollback targets)
  pkgs      List installed packages and fonts
  gc        Remove generations older than 7 days (sudo)
  status    Kernel, generation, local inputs, repo state, key services
  proxy     Proxy (mihomo / Clash core), subcommands:
              init          paste your subscription URL (hidden input); creates ~/.config/mihomo/config.yaml from the template
              on | off      start / stop the service (sudo; not started at boot, saves power)
              status        service state and whether TUN is on
              tun on|off    toggle transparent proxy (TUN) at runtime, no rebuild needed
              nodes         list the nodes of the PROXY group (current one marked)
              use <n|name>  switch node by number (from "nodes") or by exact name
  help      Show this help

Environment (optional): NIXOS_HOST=${HOST}  NIXOS_USER=${USER_NAME}  NIX_INPUTS_DIR=${INPUTS_DIR}
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
