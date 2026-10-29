#!/usr/bin/env bash
# NixOS 配置维护脚本：把常用命令封装起来，不用每次敲一长串。
#
# 关于 input 的两种模式（脚本按 flake.lock 的内容自动判断，不需要手动切换）：
#   - 正式模式：flake.lock 里有 noctalia，说明已经用 `nx update` 生成过真正的锁，
#     nixpkgs / home-manager / noctalia 由锁固定到 GitHub 上的具体版本，不需要任何覆盖参数。
#   - 过渡模式：锁还是模板自带的旧锁（没有 noctalia）。这台机器直连 GitHub 很慢，
#     所以用 ~/nix-inputs/ 里预先下载的本地源码副本做 --override-input，避免现下载。
#     跑一次 `nx update` 就会切换到正式模式。
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

# 所有 nix 命令共用的覆盖参数。判断标准：flake.lock 里有没有 noctalia
# （模板自带的旧锁没有它）。有 = 已经是 `nx update` 生成的正式锁，不需要覆盖
if grep -q '"noctalia"' flake.lock 2>/dev/null; then
  LOCAL_INPUTS=0
  OVERRIDES=()
else
  LOCAL_INPUTS=1
  OVERRIDES=(
    --override-input nixpkgs "path:${INPUTS_DIR}/nixpkgs"
    --override-input noctalia "git+file://${INPUTS_DIR}/noctalia"
    --no-write-lock-file
  )
fi

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

# 过渡模式下，本地 input 副本必须存在，否则给出明确提示而不是让 nix 报一堆难懂的错；
# 正式模式（flake.lock 已固定版本）不需要本地副本
need_inputs() {
  [ "$LOCAL_INPUTS" = 1 ] || return 0
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
  # 这一行刻意不用 lock_filter：把 nixos-rebuild 的 stderr 接进后台的过滤进程，会让它和 sudo
  # 共用的终端输出错乱（每行越缩越右的"阶梯"）。代价是 switch 时会多打印一段锁文件警告，无害
  sudo nixos-rebuild "$action" --flake ".#${HOST}" "${OVERRIDES[@]}"
  ok "nixos-rebuild ${action} completed 🎉"
  if [ "$action" = "switch" ] || [ "$action" = "test" ]; then
    echo "   Tip: open a new shell (or run: hash -r) if a newly installed command is not found."
  fi
}

# 升级 flake 的 input（nixpkgs / home-manager / noctalia）并写入 flake.lock。
# 需要访问 GitHub，这台机器上必须经过代理，所以要求 mihomo 在运行（nx proxy on）；
# 下载会走本机代理端口 7890，不管 TUN 开没开都行。
# 用法：nx update [input...]，不带参数更新全部，如 `nx update nixpkgs` 只更新 nixpkgs。
# 只改 flake.lock，不构建、不切换：之后 `nx diff` 预览软件包变化，满意再 `nx switch`，
# 不满意可以 `git checkout flake.lock` 退回上一个版本（这是有锁文件的好处）
cmd_update() {
  stage
  local before after
  before="$(sha256sum flake.lock 2>/dev/null | cut -d' ' -f1 || true)"
  say "Updating flake inputs (nixpkgs is ~45 MB; this can take several minutes)"
  nix flake update "$@"
  after="$(sha256sum flake.lock | cut -d' ' -f1)"
  if [ "$before" = "$after" ]; then
    ok "flake.lock is already up to date"
  else
    ok "flake.lock updated"
    if [ "$LOCAL_INPUTS" = 1 ]; then
      echo "   First real lock generated: from now on nx pins nixpkgs/home-manager/noctalia from GitHub"
      echo "   and no longer uses the local copies in ${INPUTS_DIR} (you can delete them later)."
    fi
    echo "   Review:  git diff flake.lock"
    echo "   Preview: $(basename "$0") diff      Apply: $(basename "$0") switch      Undo: git checkout flake.lock"
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

  if [ "$LOCAL_INPUTS" = 1 ]; then
    say "Inputs: local source copies (flake.lock is not pinned yet; run: $(basename "$0") update)"
    for d in nixpkgs noctalia; do
      if [ -d "${INPUTS_DIR}/${d}" ]; then echo "   ✅ ${d}"; else echo "   ❌ ${d} (missing!)"; fi
    done
    if [ -d "${INPUTS_DIR}/noctalia/.git" ]; then
      echo "   noctalia commit: $(git -C "${INPUTS_DIR}/noctalia" log --oneline -1)"
    fi
  else
    say "Inputs: pinned by flake.lock (GitHub)"
    echo "   flake.lock last changed: $(stat -c %y flake.lock | cut -d. -f1)"
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
# 订阅地址单独存一份，供 `proxy update` 重新下载订阅用（权限 600，和配置文件一样不进 git）
PROXY_SUB_URL_FILE="${MIHOMO_SUB_URL_FILE:-$(dirname "$PROXY_CONF")/subscription.url}"
# 订阅服务器常按 User-Agent 决定返回什么格式；clash.meta 通常会拿到 Clash/mihomo 的 YAML
PROXY_UA="${MIHOMO_UA:-clash.meta}"

# 订阅里常混着几条展示用的假节点（官网、续费入口、剩余流量、到期时间），不是真节点，
# 所以在节点列表里隐藏、也不允许按编号选中
PROXY_INFO_RE='://|剩余|重置|到期|官网|续费|过滤'

# 当前使用的节点组：订阅的节点组名因服务商而异（你的订阅里是 FSCloud）。
# 默认取规则里最后一条 MATCH 指向的组，也可用环境变量 MIHOMO_GROUP 指定
proxy_group() {
  if [ -n "${MIHOMO_GROUP:-}" ]; then printf '%s' "$MIHOMO_GROUP"; return 0; fi
  [ -f "$PROXY_CONF" ] || return 1
  grep -E 'MATCH,' "$PROXY_CONF" | tail -1 | sed -E 's/.*MATCH,([^,"'"'"']*).*/\1/'
}

# 把字符串按字节做百分号编码，节点组名含中文或特殊字符时才能放进 URL 路径
proxy_urlenc() {
  local LC_ALL=C s="$1" i c out=""
  for (( i = 0; i < ${#s}; i++ )); do
    c="${s:i:1}"
    case "$c" in
      [a-zA-Z0-9._~-]) out+="$c" ;;
      *) out+="$(printf '%%%02X' "'$c")" ;;
    esac
  done
  printf '%s' "$out"
}

# 预先下载 geoip.metadb：订阅规则里的 GEOIP,CN 需要它。mihomo 启动时找不到会自己下载，
# 但这台机器上下载很慢（8.4MB 实测 51 秒），超过它的 90 秒超时就整个服务起不来。
# 所以在这里（用户态，超时宽松、自动重试）先下载好，服务启动前由 root 复制进它的状态目录
# （见 modules/nixos/mihomo.nix 的 ExecStartPre）。下载地址取自基础设置里的 geox-url.mmdb
PROXY_GEODB="${MIHOMO_GEODB:-$(dirname "$PROXY_CONF")/geoip.metadb}"
proxy_fetch_geodata() {
  local url via=()
  url="$(grep -m1 -E '^  mmdb:' examples/mihomo/config.example.yaml | sed -E 's/^  mmdb: *"?([^"]*)"?.*/\1/')"
  # mihomo 在运行就走它的本地代理端口下载（直连镜像只有约 100KB/s，经代理快得多）；没运行就直连
  if systemctl is-active --quiet mihomo; then via=(-x "http://127.0.0.1:${PROXY_PORT}"); fi
  if [ -z "$url" ]; then warn "no geox-url.mmdb in the base settings; skipping the geoip.metadb download"; return 0; fi
  say "Downloading geoip.metadb (about 8 MB; the mirror can be slow, up to a few minutes)"
  if curl -fL "${via[@]}" --retry 3 --retry-delay 2 -m 300 -o "${PROXY_GEODB}.part" "$url" 2>/dev/null; then
    mv "${PROXY_GEODB}.part" "$PROXY_GEODB"
    ok "Saved ${PROXY_GEODB}"
  else
    rm -f "${PROXY_GEODB}.part"
    warn "geoip.metadb download failed; mihomo will try to download it itself on start (may time out). Retry: $(basename "$0") proxy update"
  fi
}

# 通过 mihomo 的本地 API 读取节点组信息；不依赖 jq，用 grep/sed 解析 JSON
proxy_group_json() { curl -sf -m 8 "http://${PROXY_API}/proxies/$(proxy_urlenc "$(proxy_group)")"; }

# 下载订阅并拼装配置：基础设置（examples/mihomo/config.example.yaml）+ 订阅里的
# proxies / proxy-groups / rules（以及 providers）。订阅里的端口、DNS、TUN 等其余设置丢弃，
# 以基础设置为准。订阅地址会被 curl 的错误输出隐藏，不会打印到屏幕。
# 测试/离线时可以用环境变量 MIHOMO_SUB_FILE 指向一个本地文件，代替下载
proxy_build_config() {
  local url="$1" raw out size rc=0
  raw="$(mktemp)"; out="$(mktemp)"
  if [ -n "${MIHOMO_SUB_FILE:-}" ]; then
    cp "$MIHOMO_SUB_FILE" "$raw"
  else
    curl -fsSL -m 60 -A "$PROXY_UA" "$url" -o "$raw" 2>/dev/null || rc=$?
    if [ "$rc" -ne 0 ]; then
      rm -f "$raw" "$out"
      die "downloading the subscription failed (curl exit ${rc}); check the URL and your network (is the subscription host reachable without a proxy?)"
    fi
  fi
  size="$(wc -c < "$raw")"
  if ! grep -q -E '^(proxies|proxy-providers):' "$raw"; then
    rm -f "$raw" "$out"
    die "the subscription did not return a Clash/mihomo YAML config (${size} bytes). The server may pick the format by User-Agent; try: MIHOMO_UA=clash-verge $(basename "$0") proxy init"
  fi
  cp examples/mihomo/config.example.yaml "$out"
  awk '
    /^[A-Za-z0-9_-]+:/ {
      key = $1; sub(/:.*/, "", key)
      keep = (key == "proxies" || key == "proxy-groups" || key == "proxy-providers" || key == "rules" || key == "rule-providers")
    }
    keep { print }
  ' "$raw" >> "$out"
  rm -f "$raw"
  grep -q -E '^proxy-groups:' "$out" || warn "the subscription has no proxy-groups; nodes cannot be switched with 'proxy use'"
  grep -q -E '^rules:' "$out" || warn "the subscription has no rules; mihomo will send everything DIRECT"
  mkdir -p "$(dirname "$PROXY_CONF")"
  chmod 700 "$(dirname "$PROXY_CONF")"
  install -m 600 "$out" "$PROXY_CONF"
  rm -f "$out"
}
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
      # 只需要输入订阅地址：下载订阅，取其中的节点、节点组和规则，拼上我们的基础设置，生成配置。
      # 地址用 read -s 读取：输入不回显，也不会进命令历史或进程参数列表
      local url
      read -r -s -p "Paste your subscription URL (input is hidden): " url
      echo
      case "$url" in http://*|https://*) ;; *) die "that does not look like an http(s) URL" ;; esac
      case "$url" in *[[:space:]]*) die "the URL must not contain spaces" ;; esac
      say "Downloading the subscription and building the config"
      proxy_build_config "$url"
      mkdir -p "$(dirname "$PROXY_SUB_URL_FILE")"
      (umask 077; printf '%s\n' "$url" > "$PROXY_SUB_URL_FILE")
      chmod 600 "$PROXY_SUB_URL_FILE"
      ok "Config written to ${PROXY_CONF} (mode 600, never commit it)"
      proxy_fetch_geodata
      echo "   Subscription URL kept in ${PROXY_SUB_URL_FILE} (mode 600) for '$(basename "$0") proxy update'"
      say "Next: $(basename "$0") proxy on"
      ;;
    update)
      # 重新下载订阅刷新节点和规则（节点会变，订阅是静态拼进配置的，需要手动更新）
      [ -f "$PROXY_SUB_URL_FILE" ] || die "no saved subscription URL; run '$(basename "$0") proxy init' first"
      say "Re-downloading the subscription and rebuilding the config"
      proxy_build_config "$(head -1 "$PROXY_SUB_URL_FILE")"
      ok "Config updated: ${PROXY_CONF}"
      proxy_fetch_geodata
      if systemctl is-active --quiet mihomo; then
        warn "mihomo is running with the old config; apply it with: $(basename "$0") proxy off && $(basename "$0") proxy on"
      fi
      ;;
    on)
      [ -f "$PROXY_CONF" ] || die "no config file; run '$(basename "$0") proxy init' first"
      grep -q -E '^(proxies|proxy-providers):' "$PROXY_CONF" \
        || die "the config has no proxies; run '$(basename "$0") proxy init' to build it from your subscription"
      [ -f "$PROXY_GEODB" ] \
        || warn "no geoip.metadb yet; mihomo will download it itself and may time out (run: $(basename "$0") proxy update)"
      sudo systemctl start mihomo
      ok "mihomo started 🚀"
      echo "   Local HTTP/SOCKS proxy: http://127.0.0.1:${PROXY_PORT}  (e.g. https_proxy=http://127.0.0.1:${PROXY_PORT} git push)"
      echo "   TUN (transparent proxy) is on by default, so every program goes through it; turn it off with: $(basename "$0") proxy tun off"
      echo "   First start downloads geoip.metadb from the mirror; if it does not come up, see: journalctl -u mihomo -b"
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
      say "Members of group $(proxy_group) (info-only entries from the subscription are hidden)"
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
      curl -sf -m 8 -X PUT "http://${PROXY_API}/proxies/$(proxy_urlenc "$(proxy_group)")" -H 'Content-Type: application/json' \
        -d "{\"name\":\"${name}\"}" >/dev/null \
        || die "switching failed; check the exact name with: $(basename "$0") proxy nodes"
      ok "Switched $(proxy_group) to: ${name}"
      ;;
    usage)
      # 流量：机场订阅的总用量（订阅响应头 subscription-userinfo，和手机上看到的一致），
      # 以及 mihomo 本次启动以来转发的流量（重启清零）。订阅地址只在本机读取，不会打印
      [ -f "$PROXY_SUB_URL_FILE" ] || die "no saved subscription URL; run '$(basename "$0") proxy init' first"
      local hdr info
      hdr="$(curl -s -m 20 -D - -o /dev/null -A "$PROXY_UA" "$(head -1 "$PROXY_SUB_URL_FILE")" | tr -d '\r' || true)"
      info="$(printf '%s\n' "$hdr" | grep -i '^subscription-userinfo:' | head -1 | cut -d: -f2- || true)"
      if [ -n "$info" ]; then
        say "Subscription quota"
        printf '%s\n' "$info" | awk -F';' '
          function hum(b) { split("B KiB MiB GiB TiB", u, " "); i = 1; while (b >= 1024 && i < 5) { b /= 1024; i++ } return sprintf("%.2f %s", b, u[i]) }
          { for (k = 1; k <= NF; k++) { gsub(/ /, "", $k); split($k, kv, "="); v[kv[1]] = kv[2] } }
          END {
            used = v["upload"] + v["download"]; total = v["total"]
            printf "   used      %s  (up %s / down %s)\n", hum(used), hum(v["upload"]), hum(v["download"])
            if (total > 0) printf "   total     %s   remaining %s   (%.1f%% used)\n", hum(total), hum(total - used), used * 100 / total
            if (v["expire"] > 0) { cmd = "date -d @" v["expire"] " +%Y-%m-%d"; cmd | getline d; close(cmd); printf "   expires   %s\n", d }
          }'
      else
        warn "the subscription server did not return a quota header (subscription-userinfo); not all providers send it"
      fi
      if systemctl is-active --quiet mihomo; then
        say "This mihomo run (resets when the service restarts)"
        curl -s -m 5 "http://${PROXY_API}/connections" | grep -oE '"(downloadTotal|uploadTotal)":[0-9]+' | tr -d '"' | awk -F: '
          function hum(b) { split("B KiB MiB GiB TiB", u, " "); i = 1; while (b >= 1024 && i < 5) { b /= 1024; i++ } return sprintf("%.2f %s", b, u[i]) }
          { v[$1] = $2 } END { printf "   download  %s\n   upload    %s\n", hum(v["downloadTotal"]), hum(v["uploadTotal"]) }'
      else
        echo "   mihomo is not running, so no per-run counters"
      fi
      ;;
    *) die "unknown proxy subcommand: ${sub} (init|update|on|off|status|tun|nodes|use|usage; see: $(basename "$0") proxy help)" ;;
  esac
}

# proxy 子命令的说明行（主帮助和 `proxy help` 共用，只在这里维护一份）
proxy_usage_lines() {
  cat <<EOF
              init          paste your subscription URL (hidden input); downloads it and builds ~/.config/mihomo/config.yaml
              update        re-download the saved subscription to refresh nodes and rules
              on | off      start / stop the service (sudo; not started at boot, saves power)
              status        service state, current node and whether TUN is on (default)
              tun on|off    toggle transparent proxy (TUN) at runtime, no rebuild needed
              nodes         list the members of the current node group (current one marked)
              use <n|name>  switch node by number (from "nodes") or by exact name
              usage         subscription quota (used / total / expiry) and traffic since this mihomo run started
EOF
}

proxy_usage() {
  cat <<EOF
Usage: $(basename "$0") proxy [subcommand]

Proxy (mihomo / Clash core). Without a subcommand it shows the status.

Subcommands:
$(proxy_usage_lines)
  help      Show this help

Environment (optional):
  MIHOMO_CONF=${PROXY_CONF}
  MIHOMO_GROUP=<group>   node group used by nodes/use (default: the group of the last MATCH rule, now: $(proxy_group 2>/dev/null || echo unknown))
  MIHOMO_UA=${PROXY_UA}   User-Agent used to download the subscription
  MIHOMO_PORT=${PROXY_PORT}  MIHOMO_API=${PROXY_API}
EOF
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
  update    Update flake inputs (nixpkgs, home-manager, noctalia) into flake.lock
            "update nixpkgs" updates only that input. Does not build or switch; preview with: diff
  gens      List all system generations (rollback targets)
  pkgs      List installed packages and fonts
  gc        Remove generations older than 7 days (sudo)
  status    Kernel, generation, local inputs, repo state, key services
  proxy     Proxy (mihomo / Clash core), subcommands (details: proxy help):
$(proxy_usage_lines)
  help      Show this help (also: -h, --help; works after any command, e.g. "proxy --help")

Environment (optional): NIXOS_HOST=${HOST}  NIXOS_USER=${USER_NAME}  NIX_INPUTS_DIR=${INPUTS_DIR}
EOF
}

# 任何命令后面带 -h / --help 都只显示帮助，不去执行（例如 `nx switch --help` 不会真的切换系统）
if [ "${2:-}" = "-h" ] || [ "${2:-}" = "--help" ]; then
  case "${1:-}" in proxy) proxy_usage ;; *) usage ;; esac
  exit 0
fi

case "${1:-help}" in
  check)  cmd_check ;;
  build)  cmd_build ;;
  diff)   cmd_diff ;;
  test)   rebuild test ;;
  boot)   rebuild boot ;;
  switch) rebuild switch ;;
  update) shift; cmd_update "$@" ;;
  gens)   cmd_gens ;;
  pkgs)   cmd_pkgs ;;
  gc)     cmd_gc ;;
  status) cmd_status ;;
  proxy)  shift; case "${1:-}" in help|-h|--help) proxy_usage ;; *) cmd_proxy "$@" ;; esac ;;
  help|-h|--help) usage ;;
  *) usage; exit 1 ;;
esac
