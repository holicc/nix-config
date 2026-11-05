# 系统相关命令：check / build / diff / test / boot / switch / update / upstream / gens / pkgs / gc / status。
# 每个命令是一个 cmd_<名字> 函数，命令名和说明登记在 nixos.sh 的 COMMANDS 表里。
# 由 nixos.sh source 进来，不单独运行。

# 校验：求值系统配置 + 用 niri 校验生成的 config.kdl（不构建，几十秒内完成）
cmd_check() {
  stage
  say "Evaluating system configuration (syntax, options, references)"
  flake_attr config.system.build.toplevel.drvPath >/dev/null
  ok "System configuration evaluates"

  say "Validating generated Niri config"
  # 不用 trap 清理临时文件：RETURN trap 是全局的，函数返回后依然有效，
  # 会在别的函数返回时再次触发，那时局部变量已不存在（set -u 下会报 unbound variable）
  local tmp niri_ok=1
  tmp="$(mktemp --suffix=.kdl)"
  flake_attr "config.home-manager.users.${USER_NAME}.xdg.configFile.\"niri/config.kdl\".text" > "$tmp" || niri_ok=0
  if [ "$niri_ok" = 1 ] && niri validate -c "$tmp" 2>&1 | grep -v -E 'DEBUG.*niri_config'; then :; else niri_ok=0; fi
  rm -f "$tmp"
  [ "$niri_ok" = 1 ] || die "Niri config validation failed (see output above)"
  ok "Niri config is valid"
  ok "All checks passed 🎉"
}

cmd_build() {
  stage
  say "Building (no switch)"
  local path
  path="$(build_path)"
  ok "Build finished: ${path}"
}

# 对比当前运行的系统和新构建的系统：只列出软件包的增删和版本变化
cmd_diff() {
  stage
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

# test / boot / switch 共用：先校验再交给 nixos-rebuild
rebuild() {
  local action="$1"
  say "Checking configuration first"
  cmd_check
  say "Running: sudo nixos-rebuild ${action}"
  sudo nixos-rebuild "$action" --flake ".#${HOST}"
  ok "nixos-rebuild ${action} completed 🎉"
  if [ "$action" = "switch" ] || [ "$action" = "test" ]; then
    echo "   Tip: open a new shell (or run: hash -r) if a newly installed command is not found."
  fi
}
cmd_test()   { rebuild test; }
cmd_boot()   { rebuild boot; }
cmd_switch() { rebuild switch; }

# 青简源码是固定在发布版 tag 上的 flake input（flake.nix 里的 github:仓库/tag）。
# 明确写 `nx update qingjian` 时，先查 GitHub 上最新的发布版，把 flake.nix 里的 tag 改成它，
# 再更新锁；不带参数的全量更新不动这个 tag，避免一次升级带上意外的新版本
QINGJIAN_REPO="qingjian-team/qingjian"
bump_qingjian_tag() {
  local latest current
  latest="$(curl -fsSL -m 20 "https://api.github.com/repos/${QINGJIAN_REPO}/releases/latest" \
    | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -1)" || true
  [ -n "$latest" ] || die "could not look up the latest ${QINGJIAN_REPO} release (GitHub unreachable? try: https_proxy=http://127.0.0.1:7890 ${PROG} update qingjian)"
  current="$(sed -n "s#.*github:${QINGJIAN_REPO}/\([^\"]*\)\".*#\1#p" flake.nix | head -1)"
  [ -n "$current" ] || die "no github:${QINGJIAN_REPO}/<tag> input found in flake.nix"
  if [ "$latest" = "$current" ]; then
    ok "qingjian is already on the latest release (${latest})"
  else
    sed -i "s#github:${QINGJIAN_REPO}/${current}\"#github:${QINGJIAN_REPO}/${latest}\"#" flake.nix
    ok "qingjian release: ${current} -> ${latest} (flake.nix)"
  fi
}

# 不带参数的 `nx update` 默认跳过的 input：更新它会触发很长的本机编译（neomacs 最后一步单线程 LTO 要几十分钟）。
# 想一并更新，加 --all；想只更新它，点名：`nx update neomacs`。要加别的 input，写进这个数组。
# 注意：`nx switch` 本身从不更新 input，只按 flake.lock 构建；这里只管 `nx update`。
UPDATE_SKIP=(neomacs)

# 升级 flake 的 input 并写入 flake.lock。
# 用法：
#   nx update              更新全部，但跳过 UPDATE_SKIP 里的（默认只有 neomacs）
#   nx update --all        更新全部，包括 UPDATE_SKIP 里的
#   nx update <input>...   只更新点名的，如 `nx update nixpkgs`、`nx update neomacs`（--all 不能和名字一起用）
# 只改 flake.lock（青简会同时改 flake.nix 里的 tag），不构建、不切换：之后 `nx diff` 预览软件包变化，
# 满意再 `nx switch`，不满意可以 `git checkout flake.lock flake.nix` 退回上一个版本。
# 直连 GitHub 很慢，需要代理时自己带环境变量：https_proxy=http://127.0.0.1:7890 nx update
cmd_update() {
  stage
  local before after arg all=0
  local -a names=() targets=()
  for arg in "$@"; do
    if [ "$arg" = --all ]; then all=1; else names+=("$arg"); fi
  done
  if [ "$all" = 1 ] && [ ${#names[@]} -gt 0 ]; then
    die "--all and input names cannot be combined: use '${PROG} update --all' or '${PROG} update <input>'"
  fi
  for arg in ${names[@]+"${names[@]}"}; do
    if [ "$arg" = qingjian ]; then bump_qingjian_tag; fi
  done
  if [ ${#names[@]} -gt 0 ]; then
    targets=("${names[@]}")
  elif [ "$all" = 0 ]; then
    # 不带参数：取 flake.lock 里所有顶层 input，去掉 UPDATE_SKIP
    mapfile -t targets < <(jq -r '.nodes.root.inputs | keys[]' flake.lock | grep -vxF -f <(printf '%s\n' "${UPDATE_SKIP[@]}"))
    say "Skipping ${UPDATE_SKIP[*]} (include with '${PROG} update --all', or update by name: '${PROG} update ${UPDATE_SKIP[0]}')"
  fi
  # --all：targets 留空，nix flake update 不带名字就是更新全部
  before="$(cat flake.lock flake.nix | sha256sum | cut -d' ' -f1)"
  say "Updating flake inputs (nixpkgs is ~45 MB; this can take several minutes)"
  nix flake update ${targets[@]+"${targets[@]}"}
  after="$(cat flake.lock flake.nix | sha256sum | cut -d' ' -f1)"
  if [ "$before" = "$after" ]; then
    ok "flake.lock is already up to date"
  else
    ok "flake.lock updated"
    echo "   Review:  git diff flake.nix flake.lock"
    echo "   Preview: ${PROG} diff      Apply: ${PROG} switch      Undo: git checkout flake.nix flake.lock"
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

# 只保留最新的 N 个系统版本（含当前这个），更旧的删掉并回收空间；之后无法回滚到被删掉的版本。
# 个数写在 KEEP_GENERATIONS，要改个数改这一个值。
# `--delete-generations +N` 表示"保留最新的 N 个"，当前正在用的版本一定在其中。
# 先删版本链接，再 nix-collect-garbage 回收只被这些旧版本引用的软件包，空间才会真正释放
KEEP_GENERATIONS=5
cmd_gc() {
  say "Keeping only the newest ${KEEP_GENERATIONS} system generations (you cannot roll back to older ones afterwards)"
  sudo nix-env --profile /nix/var/nix/profiles/system --delete-generations "+${KEEP_GENERATIONS}"
  sudo nix-collect-garbage
  # 用户自己的 profile（默认 profile）也同样只留最新的几个，再回收一次
  nix-env --delete-generations "+${KEEP_GENERATIONS}" >/dev/null 2>&1 || true
  nix-collect-garbage
  ok "Garbage collection done: ${KEEP_GENERATIONS} generations kept"
}

# 一屏看清当前状态
cmd_status() {
  say "Kernel and system generation"
  echo "   kernel: $(uname -r)"
  echo "   system: $(readlink /run/current-system)"

  say "Inputs: pinned by flake.lock (GitHub)"
  echo "   flake.lock last changed: $(stat -c %y flake.lock | cut -d. -f1)"

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

# 上游某个提交的默认内核版本。只下载两个小文件（raw.githubusercontent.com），
# 不用 `nix eval github:...`：那会把整个 nixpkgs 压缩包下载下来，直连时要好几分钟
upstream_default_kernel() {
  local raw="https://raw.githubusercontent.com/NixOS/nixpkgs/$1" series
  series="$(curl -fsS -m 20 "${raw}/pkgs/top-level/linux-kernels.nix" \
    | sed -nE 's/^ *linux_default = packages\.linux_([0-9]+)_([0-9]+);.*/\1.\2/p')" || true
  [ -n "$series" ] || { echo unknown; return; }
  curl -fsS -m 20 "${raw}/pkgs/os-specific/linux/kernel/kernels-org.json" \
    | jq -r --arg s "$series" '.[$s].version // "unknown"' || echo unknown
}

# 对比本地与上游（只读，不改任何文件）：锁定的提交 vs 分支最新提交、内核版本、上游有哪些 channel 分支。
# 查到有新版本后：nx update nixpkgs → nx diff → nx boot（内核要重启才生效）
cmd_upstream() {
  local kpath_ver='s|.*-linux-([^/]+)/.*|\1|'
  local booted current
  booted="$(readlink -f /run/booted-system/kernel | sed -E "$kpath_ver")"
  current="$(readlink -f /run/current-system/kernel | sed -E "$kpath_ver")"

  say "Local kernel"
  echo "   running: $(uname -r)"
  echo "   current system: ${current}"
  [ "$booted" = "$current" ] || warn "current system has a different kernel than the booted one: reboot to use ${current}"

  local name node ref want_ref locked_rev locked_ts remote_rev up_kernel
  for name in nixpkgs nixpkgs-unstable; do
    # flake.lock 里的节点名不一定等于 input 名（别的 input 自带同名依赖时会改叫 nixpkgs_2），
    # 所以先从 root 查出本仓库这个 input 真正指向的节点
    node="$(jq -r --arg n "$name" '.nodes.root.inputs[$n]' flake.lock)"
    ref="$(jq -r --arg n "$node" '.nodes[$n].original.ref' flake.lock)"
    locked_rev="$(jq -r --arg n "$node" '.nodes[$n].locked.rev' flake.lock)"
    locked_ts="$(jq -r --arg n "$node" '.nodes[$n].locked.lastModified' flake.lock)"
    # flake.nix 里声明的分支（想要的）和 flake.lock 里记录的分支（实际锁的）应该一致
    want_ref="$(sed -nE "s|^ *${name}\.url = \"github:NixOS/nixpkgs/([^\"]+)\".*|\1|p" flake.nix)"
    say "input: ${name}"
    echo "   branch (flake.nix):  ${want_ref:-unknown}"
    echo "   branch (flake.lock): ${ref}"
    if [ -n "$want_ref" ] && [ "$want_ref" != "$ref" ]; then
      warn "flake.lock was locked from a different branch than flake.nix declares: check 'git diff flake.lock'"
    fi
    echo "   locked commit:   ${locked_rev:0:7} ($(date -d "@${locked_ts}" +%F))"
    remote_rev="$(timeout 30 git ls-remote https://github.com/NixOS/nixpkgs "refs/heads/${ref}" | cut -f1 || true)"
    if [ -z "$remote_rev" ]; then
      warn "could not reach GitHub (try: https_proxy=http://127.0.0.1:7890 ${PROG} upstream)"
      continue
    fi
    echo "   upstream commit: ${remote_rev:0:7}  (latest of ${ref})"
    up_kernel="$(upstream_default_kernel "$remote_rev")"
    echo "   upstream kernel: ${up_kernel}  (local: ${current})"
    if [ "$remote_rev" = "$locked_rev" ]; then
      ok "up to date"
    else
      warn "newer commits available: ${PROG} update ${name}"
    fi
  done

  say "Upstream release branches (stable)"
  timeout 30 git ls-remote --heads https://github.com/NixOS/nixpkgs 'refs/heads/nixos-[0-9]*' \
    | sed 's|.*refs/heads/||' | grep -v -- '-small' | sort -V | tail -3 | sed 's/^/   /' || warn "could not list upstream branches"
}
