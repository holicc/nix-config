# 系统监控和剪贴板类工具。
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    btop         # 资源监控（配色由 catppuccin 自动套用）
    lsof         # 查看谁占用了端口或文件
    wl-clipboard # wl-copy / wl-paste：命令行和 Wayland 系统剪贴板互通
  ];
}
