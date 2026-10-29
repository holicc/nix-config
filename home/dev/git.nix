# git 的用户配置（用户名、邮箱、别名、diff 工具等）。目前为空。
# git 本体仍装在 nixos/modules/base.nix（系统级）：`sudo nixos-rebuild` 以 root 运行，
# 读取 flake 时需要 root 的 PATH 里有 git，只装在用户环境里会让 switch 失败。
{ ... }:
{
}
