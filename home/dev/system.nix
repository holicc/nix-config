# 系统监控和剪贴板类工具。
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    lsof # 查看谁占用了端口或文件
    wl-clipboard # wl-copy / wl-paste：命令行和 Wayland 系统剪贴板互通
  ];

  # btop 必须用 programs.btop 启用，catppuccin 才会给它套上配色（只放进 home.packages 不会生效）。
  # 配置文件由 home-manager 生成，是只读链接：要改设置就改这里，btop 界面里改的不会保存
  programs.btop = {
    enable = true;
    settings.theme_background = false; # 用终端自己的背景色，不画纯黑底
  };
}
