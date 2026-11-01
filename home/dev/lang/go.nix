# Go 工具链（全局安装）。
{ pkgs, ... }:
{
  home.packages = [
    # go：编译器和 go 命令（构建、测试、模块管理）
    pkgs.go
  ];
}
