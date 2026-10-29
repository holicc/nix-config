# Rust 工具链（全局安装）。
{ pkgs, ... }:
{
  home.packages = [
    # rustc：编译器；cargo：构建和包管理。
    # 编译需要 C 链接器（cc），目前系统里没有装，首次 cargo build 可能报找不到 linker
    pkgs.rustc
    pkgs.cargo
  ];
}
