# joe 用户级配置入口：只放基础信息和 imports，具体配置按职责拆在子目录：
#   niri/     窗口管理器 Niri：几个 .kdl 文件拼成 ~/.config/niri/config.kdl
#   noctalia/ 桌面 Shell Noctalia v5：状态栏、启动器、通知、主题等设置
# 由 flake.nix 以 NixOS 模块方式集成，`nixos-rebuild switch` 会一并应用系统配置和这里的用户配置
{ ... }:
{
  imports = [
    ./niri
    ./noctalia
  ];

  home.username = "joe";
  home.homeDirectory = "/home/joe";

  # 用户级 stateVersion，同样不要随升级改动
  home.stateVersion = "26.05";

  # 让 home-manager 管理它自己
  programs.home-manager.enable = true;
}
