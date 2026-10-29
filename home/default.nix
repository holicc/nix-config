# joe 用户级配置入口：只放基础信息和 imports，具体配置按职责拆在子目录：
#   niri/     窗口管理器 Niri：几个 .kdl 文件拼成 ~/.config/niri/config.kdl
#   noctalia/ 桌面 Shell Noctalia v5：状态栏、启动器、通知、主题等设置
#   theme/    统一配色：catppuccin/nix（Macchiato），Alacritty、btop、bat 等自动套用
#   alacritty/ 终端：字体、内边距、去标题栏（配色由 theme 提供）
#   shell/    命令行环境：Nushell + Starship 提示符
# 由 flake.nix 以 NixOS 模块方式集成，`nixos-rebuild switch` 会一并应用系统配置和这里的用户配置
{ pkgs, ... }:
{
  imports = [
    ./niri
    ./noctalia
    ./theme
    ./alacritty
    ./shell
  ];

  # nx：把 ~/nixos-config/scripts/nixos.sh 放进 PATH，在任何目录都能直接 `nx switch`、`nx check`。
  # 只是一层薄包装，真正的逻辑还在仓库里的脚本，所以改脚本不用重新 switch。
  # 限制：写死了仓库在 ~/nixos-config；仓库挪位置要同步改这里。
  # 想换命令名，改 writeShellScriptBin 的第一个参数
  home.packages = [
    (pkgs.writeShellScriptBin "nx" ''
      exec "$HOME/nixos-config/scripts/nixos.sh" "$@"
    '')
  ];

  home.username = "joe";
  home.homeDirectory = "/home/joe";

  # 用户级 stateVersion，同样不要随升级改动
  home.stateVersion = "26.05";

  # 让 home-manager 管理它自己
  programs.home-manager.enable = true;
}
