# Rust 工具链（全局安装），由 rustup 管理版本。
# rustup 自己联网下载工具链，状态在 ~/.rustup 和 ~/.cargo，不在 Nix 配置里，
# 换机器或重装后要重新执行：rustup default stable
# 它下载的是预编译二进制，NixOS 上需要系统开启 nix-ld（见 nixos/modules/nix-ld.nix）才能运行；
# 编译还需要 cc（见 home/dev/build.nix）。
# 切换版本：`cargo +nightly build`（命令行的 +工具链 优先级最高）；
# 或 `RUSTUP_TOOLCHAIN=nightly cargo build`。
#
# RUSTUP_TOOLCHAIN = "stable"：所有项目默认用本机的 stable，**不理会**项目里的 rust-toolchain.toml
# （它会让 rustup 自动下载指定版本，比如官方青简要求 1.96.0，本机 stable 更新、满足要求，没必要再下载）。
# 代价：项目如果真的需要 nightly 或某个固定版本，会用 stable 编译而可能失败，
# 这时用上面的 `cargo +nightly` 写法单独指定，或删掉这个变量让 rustup 按项目文件走。
{ pkgs, ... }:
{
  home.packages = [
    # rustup：Rust 工具链管理器
    pkgs.rustup
  ];

  # bash、SSH 登录和图形会话
  home.sessionVariables.RUSTUP_TOOLCHAIN = "stable";
  # Nushell（Alacritty 直接启动 nu，不一定经过 bash 登录脚本，所以这里单独设一份）
  programs.nushell.environmentVariables.RUSTUP_TOOLCHAIN = "stable";
}
