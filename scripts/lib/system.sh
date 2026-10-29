# 系统相关命令：check / build / diff / test / boot / switch / update / gens / pkgs / gc / status。
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

# 升级 flake 的 input 并写入 flake.lock。
# 用法：nx update [input...]，不带参数更新全部，如 `nx update nixpkgs` 只更新 nixpkgs。
# 只改 flake.lock，不构建、不切换：之后 `nx diff` 预览软件包变化，满意再 `nx switch`，
# 不满意可以 `git checkout flake.lock` 退回上一个版本。
# 直连 GitHub 很慢，需要代理时自己带环境变量：https_proxy=http://127.0.0.1:7890 nx update
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
    echo "   Review:  git diff flake.lock"
    echo "   Preview: ${PROG} diff      Apply: ${PROG} switch      Undo: git checkout flake.lock"
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
