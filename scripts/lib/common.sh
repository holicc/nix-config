# 公共部分：输出函数、flake 取值、git 暂存。由 nixos.sh source 进来，不单独运行。
# 约定：脚本的运行输出统一用英文 + emoji（成功 ✅、步骤 🔹、警告 ⚠️、错误 ❌），注释保持中文。

# ---- 可通过环境变量覆盖的设置 ----
HOST="${NIXOS_HOST:-nixos-dev}"   # flake 里的 nixosConfigurations 名称
USER_NAME="${NIXOS_USER:-joe}"    # home-manager 管理的用户

# 脚本名，用在提示信息里（经 nx 包装命令调用时也是 nixos.sh）
PROG="$(basename "$0")"

# ---- 输出 ----
say()  { printf '\033[1;34m🔹 %s\033[0m\n' "$*"; }
ok()   { printf '\033[1;32m✅ %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m⚠️  %s\033[0m\n' "$*"; }
die()  { printf '\033[1;31m❌ Error: %s\033[0m\n' "$*" >&2; exit 1; }

# ---- flake ----

# flake 只认 git 已 track 的文件，新增文件后必须 git add，否则会报"文件不存在"
stage() { git add -A; }

# 求值当前主机配置里的一个属性（相对 nixosConfigurations.<主机>），按原始字符串输出
flake_attr() { nix eval --raw ".#nixosConfigurations.${HOST}.$1"; }

# 构建但不切换，只输出构建结果的 store 路径（不在仓库里留下 result 链接）
build_path() {
  nix build ".#nixosConfigurations.${HOST}.config.system.build.toplevel" --no-link --print-out-paths
}
