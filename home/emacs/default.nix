# Emacs（Neomacs）配置：由 home-manager 把 init.el 链接到 ~/.config/emacs/init.el。
# 用 mkOutOfStoreSymlink 直接指向本仓库里的文件，而不是复制进 /nix/store：
# 改 init.el 后重启 Emacs 就生效，不用 nx switch；仍在 git 里管理，但不是纯声明式。
# 限制：写死了仓库在 ~/nixos-config（和 nx 一样）；仓库挪位置要同步改这里。
# 本体见 home/dev/neomacs.nix；暂不装第三方包，只用内置功能。
# 排查方向：Emacs 没读到配置，先看 ~/.config/emacs/init.el 是否是指向本仓库的软链，
# 并确认没有 ~/.emacs 或 ~/.emacs.d（它们优先级更高）。
{ config, ... }:
let
  dir = "${config.home.homeDirectory}/nixos-config/home/emacs";
in
{
  xdg.configFile."emacs/init.el".source = config.lib.file.mkOutOfStoreSymlink "${dir}/init.el";
}
