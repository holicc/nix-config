# Shell 脚本工具：给 Emacs（Doom 的 sh 模块）的格式化和检查用，命令行也能直接用。
# 本仓库的 scripts/nixos.sh 和 scripts/lib/*.sh 就是 bash 脚本，可以用它们检查。
# 排查方向：Emacs 里没有 shell 检查提示，先看 `which shellcheck`，再看 `M-x flycheck-verify-setup`。
{ pkgs, ... }:
{
  home.packages = [
    # shellcheck：shell 脚本静态检查（引号、未定义变量、可移植性等常见错误）
    pkgs.shellcheck
    # shfmt：shell 脚本格式化，保存时由 Doom 的 format 模块调用
    pkgs.shfmt
  ];
}
