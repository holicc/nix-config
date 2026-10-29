# Python 工具链（全局安装）。
{ pkgs, ... }:
{
  home.packages = [
    # python3：解释器
    pkgs.python3
  ];
}
