# Emacs（Neomacs）+ Doom Emacs 的配置：由 home-manager 把 Doom 的三个配置文件链接到 ~/.config/doom/。
# 用 mkOutOfStoreSymlink 直接指向本仓库里的文件，而不是复制进 /nix/store：
# 改文件后重启 Emacs 就生效，不用 nx switch；仍在 git 里管理，但不是纯声明式。
# 限制：写死了仓库在 ~/nixos-config（和 nx 一样）；仓库挪位置要同步改这里。
#
# 文件分工（Doom 的约定）：
#   init.el      启用哪些 Doom 模块（改了要 `doom sync`）；本配置启用了 evil（Vim 键位）
#   config.el    个人设置：字体、主题、变量（改了重启即可）
#   packages.el  额外要装的包（改了要 `doom sync`）
#
# Doom 本体不在 Nix 里管：它要克隆到 ~/.config/emacs，包由 straight.el 联网安装，状态在 ~/.config/emacs/.local，
# 所以 Doom 的包版本不可复现。首次安装（本机已有 git、ripgrep、fd）：
#   git clone --depth 1 https://github.com/doomemacs/doomemacs ~/.config/emacs
#   ~/.config/emacs/bin/doom install
# 之后改 init.el / packages.el 用 `~/.config/emacs/bin/doom sync`。
# Neomacs 本体见 home/dev/neomacs.nix；它提供 emacs 命令，所以 bin/doom 调用的 emacs 就是 Neomacs。
# 排查方向：Emacs 没读到配置，确认没有 ~/.emacs 或 ~/.emacs.d（它们优先级更高，Neomacs 首次运行可能自动创建空的 ~/.emacs.d，空目录可以直接 rmdir）；
# 并确认 ~/.config/emacs 是 Doom 的克隆，而不是 home-manager 的软链。
{ config, ... }:
let
  dir = "${config.home.homeDirectory}/nixos-config/home/emacs";
  link = config.lib.file.mkOutOfStoreSymlink;
in
{
  xdg.configFile = {
    "doom/init.el".source = link "${dir}/init.el";
    "doom/config.el".source = link "${dir}/config.el";
    "doom/packages.el".source = link "${dir}/packages.el";
  };
}
