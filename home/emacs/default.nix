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
# 之后改 init.el / packages.el 用 `doom sync`（~/.config/emacs/bin 已加进 PATH，见下面的 home.sessionPath；
# 刚 switch 完要新开终端才有）。
# Neomacs 本体见 home/dev/neomacs.nix；它提供 emacs 命令，所以 bin/doom 调用的 emacs 就是 Neomacs。
# 排查方向：Emacs 没读到配置，确认没有 ~/.emacs 或 ~/.emacs.d（它们优先级更高，Neomacs 首次运行可能自动创建空的 ~/.emacs.d，空目录可以直接 rmdir）；
# 并确认 ~/.config/emacs 是 Doom 的克隆，而不是 home-manager 的软链。
{ config, pkgs, ... }:
let
  dir = "${config.home.homeDirectory}/nixos-config/home/emacs";
  link = config.lib.file.mkOutOfStoreSymlink;

  # tree-sitter 语法库：用 Nix 预编译好的，不让 Doom 第一次打开文件时联网下载源码再用 gcc 现场编译。
  # 输出目录里是 libtree-sitter-<语言>.so，正是 Emacs 要的文件名；已在 Neomacs 里实测能加载、能解析。
  # 新增语言：往下面的列表里加 g.tree-sitter-<名字>（`nix eval` 看 pkgs.tree-sitter-grammars 里有哪些）。
  grammars = pkgs.emacsPackages.treesit-grammars.with-grammars (g: [
    g.tree-sitter-go
    g.tree-sitter-gomod
    g.tree-sitter-rust
    g.tree-sitter-nix
    g.tree-sitter-python
    g.tree-sitter-bash
    g.tree-sitter-javascript
    g.tree-sitter-typescript
    g.tree-sitter-tsx
    g.tree-sitter-json
    g.tree-sitter-yaml
    g.tree-sitter-toml
  ]);
in
{
  # 语法库放到固定位置 ~/.local/share/tree-sitter-grammars，config.el 里把它加进 treesit-extra-load-path。
  # 排查方向：某个语言没有 tree-sitter 高亮，`M-x treesit-language-available-p` 看该语言能否加载，
  # 并确认这个目录存在、里面有对应的 .so。
  xdg.dataFile."tree-sitter-grammars".source = "${grammars}/lib";

  # 把 Doom 的命令行工具（doom sync、doom doctor 等）放进 PATH，不用再写全路径。
  # bash、SSH 登录和图形会话走 home.sessionPath；Nushell 不一定读那些脚本（Alacritty 直接启动 nu），
  # 所以在它的 extraConfig 里单独 path add 一份。目录在 Doom 克隆之前不存在，加进 PATH 无害。
  home.sessionPath = [ "${config.xdg.configHome}/emacs/bin" ];
  programs.nushell.extraConfig = ''
    use std/util "path add"
    path add "~/.config/emacs/bin"
  '';

  xdg.configFile = {
    "doom/init.el".source = link "${dir}/init.el";
    "doom/config.el".source = link "${dir}/config.el";
    "doom/packages.el".source = link "${dir}/packages.el";
  };
}
