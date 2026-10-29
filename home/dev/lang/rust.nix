# Rust 工具链（全局安装），由 rustup 管理版本。
# rustup 自己联网下载工具链，状态在 ~/.rustup 和 ~/.cargo，不在 Nix 配置里，
# 换机器或重装后要重新执行：rustup default stable
# 它下载的是预编译二进制，NixOS 上需要系统开启 nix-ld（见 nixos/modules/nix-ld.nix）才能运行；
# 编译还需要 cc（见 home/dev/build.nix）。
# 切换版本：rustup default nightly；某目录单独用某版本：rustup override set 1.80；
# 项目里的 rust-toolchain.toml 会被自动识别
{ pkgs, ... }:
{
  home.packages = [
    # rustup：Rust 工具链管理器
    pkgs.rustup
  ];
}
