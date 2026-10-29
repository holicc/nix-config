# 中文输入法：Fcitx5 + 拼音。
# waylandFrontend = true：在 Wayland（Niri）下通过 text-input 协议和程序通信，
# 此时 NixOS 不再设置 GTK_IM_MODULE / QT_IM_MODULE，避免和 Wayland 原生输入冲突。
# 切换中英文：Ctrl+空格（Fcitx5 默认）。
# 排查方向：某个程序里打不出中文，先看它是不是 Wayland 原生程序；
# Chrome 需要额外参数（见 browser.nix 的 commandLineArgs）；
# `fcitx5-diagnose` 会列出环境变量和模块加载情况。
{ pkgs, ... }:
{
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5 = {
      waylandFrontend = true;
      addons = [
        # 拼音引擎（含云拼音、符号表情等）
        pkgs.qt6Packages.fcitx5-chinese-addons
        # GTK 程序的输入法模块
        pkgs.fcitx5-gtk
      ];
      # 声明式的输入法组：默认英文键盘加拼音，开机即可用，不必先打开图形配置界面
      settings.inputMethod = {
        GroupOrder."0" = "Default";
        "Groups/0" = {
          Name = "Default";
          "Default Layout" = "us";
          DefaultIM = "pinyin";
        };
        "Groups/0/Items/0".Name = "keyboard-us";
        "Groups/0/Items/1".Name = "pinyin";
      };
    };
  };
}
