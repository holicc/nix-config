# Node.js 工具链（全局安装）。
{ pkgs, ... }:
{
  home.packages = [
    # nodejs：运行时，自带 npm
    pkgs.nodejs
  ];
}
