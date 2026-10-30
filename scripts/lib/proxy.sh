# 代理（mihomo，即 Clash 内核）：nx proxy <子命令>。
# 每个子命令是一个 pcmd_<名字> 函数，名字和说明登记在下面的 PROXY_COMMANDS 表里；
# proxy_ 开头的是内部辅助函数。由 nixos.sh source 进来，不单独运行。
#
# 订阅地址属于敏感信息，配置放在仓库外的 PROXY_DIR，不进 git；
# 脚本负责下载订阅、拼装配置、多配置切换、启停、切换 TUN 和节点。
#
# 多配置：每个配置一个目录 PROXY_DIR/profiles/<名字>/（config.yaml，来自订阅的还有 subscription.url），
# PROXY_CONF 是一个软链接，指向当前启用的那份 config.yaml。mihomo 服务只读 PROXY_CONF，
# 所以 nixos/modules/mihomo.nix 不用关心有几个配置。

# ---- 设置（可用环境变量覆盖）----
PROXY_CONF="${MIHOMO_CONF:-$HOME/.config/mihomo/config.yaml}"
PROXY_PORT="${MIHOMO_PORT:-7890}"
PROXY_API="${MIHOMO_API:-127.0.0.1:9090}"
PROXY_DIR="$(dirname "$PROXY_CONF")"
PROXY_PROFILES="${PROXY_DIR}/profiles"
# 订阅服务器常按 User-Agent 决定返回什么格式；clash.meta 通常会拿到 Clash/mihomo 的 YAML
PROXY_UA="${MIHOMO_UA:-clash.meta}"
PROXY_GEODB="${MIHOMO_GEODB:-${PROXY_DIR}/geoip.metadb}"
# 订阅里常混着几条展示用的假节点（官网、续费入口、剩余流量、到期时间），不是真节点，
# 所以在节点列表里隐藏、也不允许按编号选中
PROXY_INFO_RE='://|剩余|重置|到期|官网|续费|过滤'

# 子命令表："名字|说明"。主帮助和 `proxy help` 都从这里生成，加子命令时在这里登记一行
PROXY_COMMANDS=(
  "add|add <name> [file]: new profile from a Clash config file, or (no file) from a subscription URL (hidden input)"
  "list|list profiles (the active one is marked)"
  "switch|switch <name>: activate another profile (restarts mihomo if it is running; sudo)"
  "rm|rm <name>: delete a profile (not the active one)"
  "update|update [name]: re-download a subscription profile (default: the active one)"
  "on|start the service (sudo; not started at boot, saves power)"
  "off|stop the service (sudo)"
  "status|service state, current node and whether TUN is on (default)"
  "tun|tun on|off: toggle transparent proxy (TUN) at runtime, no rebuild needed"
  "nodes|list the members of the current node group (current one marked)"
  "use|use <n|name>: switch node by number (from \"nodes\") or by exact name"
  "usage|subscription quota (used / total / expiry) and traffic since this mihomo run started"
)

# awk 里把字节数换成 KiB/MiB/GiB 的函数，两处统计用到
AWK_HUM=$'function hum(b) { split("B KiB MiB GiB TiB", u, " "); i = 1; while (b >= 1024 && i < 5) { b /= 1024; i++ } return sprintf("%.2f %s", b, u[i]) }\n'

# ---- 辅助函数 ----

proxy_running() { systemctl is-active --quiet mihomo; }
proxy_need_running() {
  proxy_running || die "mihomo is not running; run '${PROG} proxy on' first"
}
proxy_need_config() {
  [ -e "$PROXY_CONF" ] || die "no active profile; run '${PROG} proxy add <name> [file]' first"
}

# 当前启用的配置名：PROXY_CONF 软链接指向 profiles/<名字>/config.yaml
proxy_current() {
  if [ -L "$PROXY_CONF" ]; then basename "$(dirname "$(readlink "$PROXY_CONF")")"; fi
}
proxy_valid_name() { [[ "${1:-}" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; }
proxy_need_profile() {
  proxy_valid_name "${1:-}" && [ -d "${PROXY_PROFILES}/$1" ] \
    || die "no profile named '${1:-}'; see: ${PROG} proxy list"
}
proxy_activate() { ln -sfn "${PROXY_PROFILES}/$1/config.yaml" "$PROXY_CONF"; }

# 订阅地址单独存在配置目录里，供 `proxy update` / `usage` 用（权限 600；从文件导入的配置没有）
proxy_sub_file() { printf '%s/%s/subscription.url' "$PROXY_PROFILES" "$1"; }
proxy_need_sub_url() {
  [ -f "$(proxy_sub_file "$1")" ] \
    || die "profile '${1}' has no subscription URL (imported from a file); re-import it: ${PROG} proxy add ${1} <file>"
}

# 旧版本只有一个 config.yaml（普通文件）：第一次使用时自动迁成名为 default 的配置
proxy_migrate() {
  [ -f "$PROXY_CONF" ] && [ ! -L "$PROXY_CONF" ] || return 0
  mkdir -p "${PROXY_PROFILES}/default"
  chmod 700 "$PROXY_DIR" "$PROXY_PROFILES" "${PROXY_PROFILES}/default"
  mv "$PROXY_CONF" "${PROXY_PROFILES}/default/config.yaml"
  if [ -f "${PROXY_DIR}/subscription.url" ]; then
    mv "${PROXY_DIR}/subscription.url" "$(proxy_sub_file default)"
  fi
  proxy_activate default
  ok "Migrated the existing config to profile 'default'"
}

# 当前使用的节点组：订阅的节点组名因服务商而异。
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

# 通过 mihomo 的本地 API 读取节点组信息；不依赖 jq，用 grep/sed 解析 JSON
proxy_group_json() { curl -sf -m 8 "http://${PROXY_API}/proxies/$(proxy_urlenc "$(proxy_group)")"; }
proxy_now() {
  proxy_group_json | grep -o '"now":"[^"]*"' | sed -e 's/^"now":"//' -e 's/"$//'
}
proxy_nodes() {
  proxy_group_json | grep -o '"all":\[[^]]*\]' \
    | sed -e 's/^"all":\["//' -e 's/"\]$//' -e 's/","/\n/g' | grep -v -E "$PROXY_INFO_RE"
}

# 预先下载 geoip.metadb：订阅规则里的 GEOIP,CN 需要它。mihomo 启动时找不到会自己下载，
# 但这台机器上下载很慢（8.4MB 实测 51 秒），超过它的 90 秒超时就整个服务起不来。
# 所以在这里（用户态，超时宽松、自动重试）先下载好，服务启动前由 root 复制进它的状态目录
# （见 nixos/modules/mihomo.nix 的 ExecStartPre）。下载地址取自基础设置里的 geox-url.mmdb
proxy_fetch_geodata() {
  local url via=()
  url="$(grep -m1 -E '^  mmdb:' examples/mihomo/config.example.yaml | sed -E 's/^  mmdb: *"?([^"]*)"?.*/\1/')"
  if [ -z "$url" ]; then warn "no geox-url.mmdb in the base settings; skipping the geoip.metadb download"; return 0; fi
  # mihomo 在运行就走它的本地代理端口下载（直连镜像只有约 100KB/s，经代理快得多）；没运行就直连
  if proxy_running; then via=(-x "http://127.0.0.1:${PROXY_PORT}"); fi
  say "Downloading geoip.metadb (about 8 MB; the mirror can be slow, up to a few minutes)"
  if curl -fL "${via[@]}" --retry 3 --retry-delay 2 -m 300 -o "${PROXY_GEODB}.part" "$url" 2>/dev/null; then
    mv "${PROXY_GEODB}.part" "$PROXY_GEODB"
    ok "Saved ${PROXY_GEODB}"
  else
    rm -f "${PROXY_GEODB}.part"
    warn "geoip.metadb download failed; mihomo will try to download it itself on start (may time out). Retry: ${PROG} proxy update"
  fi
}

# 拼装配置：基础设置（examples/mihomo/config.example.yaml）+ 来源里的
# proxies / proxy-groups / rules（以及 providers）。来源里的端口、DNS、TUN 等其余设置丢弃，
# 以基础设置为准，所以不管哪个配置，`tun`、`nodes`、`use` 都一样用。
# 参数：写到哪个文件，来源（订阅地址，或本地配置文件，二选一，另一个传空串）。
# 订阅地址会被 curl 的错误输出隐藏，不会打印到屏幕
proxy_build_config() {
  local target="$1" url="$2" file="$3" raw out size rc=0
  raw="$(mktemp)"; out="$(mktemp)"
  if [ -n "$file" ]; then
    cp "$file" "$raw"
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
    die "the source is not a Clash/mihomo YAML config (${size} bytes). For a subscription the server may pick the format by User-Agent; try: MIHOMO_UA=clash-verge ${PROG} proxy add <name>"
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
  mkdir -p "$(dirname "$target")"
  chmod 700 "$PROXY_DIR" "$PROXY_PROFILES" "$(dirname "$target")"
  install -m 600 "$out" "$target"
  rm -f "$out"
}

# ---- 子命令 ----

# 新增（或覆盖同名）配置，来源二选一：
#   add <名字> <文件>   导入你提供的 Clash/mihomo 配置文件
#   add <名字>          粘贴订阅地址，下载订阅（地址用 read -s 读取：不回显，不进命令历史和进程参数）
# 第一个配置会自动启用；之后新增的不改变当前配置，用 switch 切换
pcmd_add() {
  local name="${1:-}" file="${2:-}" url="" dir
  proxy_valid_name "$name" || die "usage: ${PROG} proxy add <name> [file]   (name: letters, digits, . _ -)"
  dir="${PROXY_PROFILES}/${name}"
  if [ -n "$file" ]; then
    [ -f "$file" ] || die "no such file: ${file}"
    say "Importing ${file} as profile '${name}'"
  else
    read -r -s -p "Paste your subscription URL (input is hidden): " url
    echo
    case "$url" in http://*|https://*) ;; *) die "that does not look like an http(s) URL" ;; esac
    case "$url" in *[[:space:]]*) die "the URL must not contain spaces" ;; esac
    say "Downloading the subscription and building profile '${name}'"
  fi
  proxy_build_config "${dir}/config.yaml" "$url" "$file"
  rm -f "$(proxy_sub_file "$name")"
  if [ -n "$url" ]; then
    (umask 077; printf '%s\n' "$url" > "$(proxy_sub_file "$name")")
    chmod 600 "$(proxy_sub_file "$name")"
  fi
  ok "Profile '${name}' saved in ${dir} (mode 600, never commit it)"
  if [ -z "$(proxy_current)" ]; then
    proxy_activate "$name"
    ok "Activated '${name}'"
    say "Next: ${PROG} proxy on"
  else
    echo "   Activate it with: ${PROG} proxy switch ${name}"
  fi
  proxy_fetch_geodata
}

pcmd_list() {
  local cur d n src
  cur="$(proxy_current)"
  say "Profiles in ${PROXY_PROFILES}"
  for d in "${PROXY_PROFILES}"/*/; do
    [ -d "$d" ] || continue
    n="$(basename "$d")"
    if [ -f "$(proxy_sub_file "$n")" ]; then src="subscription"; else src="file"; fi
    if [ "$n" = "$cur" ]; then printf '   ✅ %-16s %s (active)\n' "$n" "$src"; else printf '      %-16s %s\n' "$n" "$src"; fi
  done
  [ -n "$cur" ] || echo "   none yet; add one with: ${PROG} proxy add <name> [file]"
}

# 切换配置：改软链接；mihomo 在运行就重启让它生效（节点选择会恢复成配置里的默认）
pcmd_switch() {
  local name="${1:-}"
  proxy_need_profile "$name"
  if [ "$name" = "$(proxy_current)" ]; then ok "'${name}' is already active"; return 0; fi
  proxy_activate "$name"
  ok "Activated '${name}'"
  if proxy_running; then
    sudo systemctl restart mihomo
    ok "mihomo restarted with the new profile"
  else
    echo "   mihomo is not running; start it with: ${PROG} proxy on"
  fi
}

pcmd_rm() {
  local name="${1:-}"
  proxy_need_profile "$name"
  [ "$name" != "$(proxy_current)" ] || die "'${name}' is the active profile; switch to another one first"
  rm -r "${PROXY_PROFILES:?}/${name}"
  ok "Removed profile '${name}'"
}

# 重新下载订阅刷新节点和规则（节点会变，订阅是静态拼进配置的，需要手动更新）
pcmd_update() {
  local name="${1:-$(proxy_current)}"
  [ -n "$name" ] || die "no active profile; run '${PROG} proxy add <name> [file]' first"
  proxy_need_profile "$name"
  proxy_need_sub_url "$name"
  say "Re-downloading the subscription of '${name}' and rebuilding its config"
  proxy_build_config "${PROXY_PROFILES}/${name}/config.yaml" "$(head -1 "$(proxy_sub_file "$name")")" ""
  ok "Profile '${name}' updated"
  proxy_fetch_geodata
  if proxy_running && [ "$name" = "$(proxy_current)" ]; then
    warn "mihomo is running with the old config; apply it with: ${PROG} proxy off && ${PROG} proxy on"
  fi
}

pcmd_on() {
  proxy_need_config
  grep -q -E '^(proxies|proxy-providers):' "$PROXY_CONF" \
    || die "the active profile has no proxies; re-add it: ${PROG} proxy add <name> [file]"
  [ -f "$PROXY_GEODB" ] \
    || warn "no geoip.metadb yet; mihomo will download it itself and may time out (run: ${PROG} proxy update)"
  sudo systemctl start mihomo
  ok "mihomo started 🚀"
  echo "   Local HTTP/SOCKS proxy: http://127.0.0.1:${PROXY_PORT}  (e.g. https_proxy=http://127.0.0.1:${PROXY_PORT} git push)"
  echo "   TUN (transparent proxy) is on by default, so every program goes through it; turn it off with: ${PROG} proxy tun off"
  echo "   First start downloads geoip.metadb from the mirror; if it does not come up, see: journalctl -u mihomo -b"
}

pcmd_off() {
  sudo systemctl stop mihomo
  ok "mihomo stopped"
}

pcmd_status() {
  if proxy_running; then
    ok "mihomo service: active"
    echo "   node: $(proxy_now || echo unknown)"
    printf '   TUN: '
    curl -s "http://${PROXY_API}/configs" | grep -o '"tun":{"enable":[a-z]*' | grep -o '[a-z]*$' || echo "could not read"
  else
    warn "mihomo service: $(systemctl is-active mihomo 2>/dev/null || true)"
  fi
  if [ -e "$PROXY_CONF" ]; then echo "   profile: $(proxy_current)  (${PROXY_CONF})"; else echo "   profile: none (run: ${PROG} proxy add <name> [file])"; fi
}

# 运行时切换透明代理，不需要重新构建；需要 mihomo 已启动
pcmd_tun() {
  local state="${1:-}"
  case "$state" in on) state=true ;; off) state=false ;; *) die "usage: ${PROG} proxy tun on|off" ;; esac
  curl -sf -X PATCH "http://${PROXY_API}/configs" -H 'Content-Type: application/json' \
    -d "{\"tun\":{\"enable\":${state}}}" || die "switching failed; is mihomo running? (proxy on)"
  ok "TUN set to ${state}"
}

# 列出节点，当前使用的打 ✅；编号可直接给 `proxy use`
pcmd_nodes() {
  proxy_need_running
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
  echo "   Switch with: ${PROG} proxy use <number|name>"
}

# 切换节点：参数是 nodes 列表里的编号，或节点的完整名称。只改 mihomo 运行时选择，重启后可能恢复
pcmd_use() {
  local want="${1:-}" name=""
  [ -n "$want" ] || die "usage: ${PROG} proxy use <number|name>"
  proxy_need_running
  if [[ "$want" =~ ^[0-9]+$ ]]; then
    name="$(proxy_nodes | sed -n "${want}p" || true)"
    [ -n "$name" ] || die "no node with number ${want}; run: ${PROG} proxy nodes"
  else
    name="$want"
  fi
  case "$name" in *'"'*|*'\'*) die "node name must not contain double quotes or backslashes" ;; esac
  curl -sf -m 8 -X PUT "http://${PROXY_API}/proxies/$(proxy_urlenc "$(proxy_group)")" -H 'Content-Type: application/json' \
    -d "{\"name\":\"${name}\"}" >/dev/null \
    || die "switching failed; check the exact name with: ${PROG} proxy nodes"
  ok "Switched $(proxy_group) to: ${name}"
}

# 流量：机场订阅的总用量（订阅响应头 subscription-userinfo，和手机上看到的一致），
# 以及 mihomo 本次启动以来转发的流量（重启清零）。订阅地址只在本机读取，不会打印
pcmd_usage() {
  local name hdr info
  name="$(proxy_current)"
  proxy_need_sub_url "$name"
  hdr="$(curl -s -m 20 -D - -o /dev/null -A "$PROXY_UA" "$(head -1 "$(proxy_sub_file "$name")")" | tr -d '\r' || true)"
  info="$(printf '%s\n' "$hdr" | grep -i '^subscription-userinfo:' | head -1 | cut -d: -f2- || true)"
  if [ -n "$info" ]; then
    say "Subscription quota (profile '${name}')"
    printf '%s\n' "$info" | awk -F';' "${AWK_HUM}"'
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
  if proxy_running; then
    say "This mihomo run (resets when the service restarts)"
    curl -s -m 5 "http://${PROXY_API}/connections" | grep -oE '"(downloadTotal|uploadTotal)":[0-9]+' | tr -d '"' \
      | awk -F: "${AWK_HUM}"'{ v[$1] = $2 } END { printf "   download  %s\n   upload    %s\n", hum(v["downloadTotal"]), hum(v["uploadTotal"]) }'
  else
    echo "   mihomo is not running, so no per-run counters"
  fi
}

# ---- 分发和帮助 ----

# 子命令名用 | 连起来，用在报错里
proxy_names() {
  local entry out=""
  for entry in "${PROXY_COMMANDS[@]}"; do out+="${out:+|}${entry%%|*}"; done
  printf '%s' "$out"
}

# 子命令的说明行（主帮助和 `proxy help` 共用）。说明里的 `|` 前面是名字，所以只切第一个
proxy_usage_lines() {
  local entry
  for entry in "${PROXY_COMMANDS[@]}"; do
    printf '              %-12s  %s\n' "${entry%%|*}" "${entry#*|}"
  done
}

proxy_help() {
  cat <<EOF
Usage: ${PROG} proxy [subcommand]

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

cmd_proxy() {
  local sub="${1:-status}"
  shift || true
  case "$sub" in help|-h|--help) proxy_help; return 0 ;; esac
  proxy_migrate
  declare -F "pcmd_${sub}" >/dev/null \
    || die "unknown proxy subcommand: ${sub} ($(proxy_names); see: ${PROG} proxy help)"
  "pcmd_${sub}" "$@"
}
