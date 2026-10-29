# 构建类工具。
{ pkgs, ... }:
{
  home.packages = [
    # gcc：C 编译器，提供 cc 和 gcc 命令。
    # Rust 链接可执行文件、Go 的 cgo、Node 编译原生模块都需要系统里有 cc，NixOS 默认没有
    pkgs.gcc
  ];
}
