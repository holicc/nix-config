# 系统主配置：只负责引入各子模块，具体内容拆分在 modules/nixos/ 下
#
# 提示：Rust 开发环境走项目级 `nix develop`，不在系统全局安装。
# 模板位置：examples/rust-flake-template/flake.nix（复制到项目根目录即可使用）
#
# 历史坑点：
# - /boot 的 fmask/dmask 修改后必须整机重启才生效，switch 不会让 vfat 选项生效
# - 不要在 Live 安装环境里执行 nixos-rebuild（改的是 Live 系统自身）
# - system.stateVersion 保持 "26.05"，不要随升级改动
{ ... }:
{
  imports = [
    # 硬件配置：由 nixos-generate-config 生成，已在机器上，勿手改
    ./hardware-configuration.nix

    ../modules/nixos/base.nix   # 主机名/时区/引导/SSH/用户/全局工具
    ../modules/nixos/power.nix  # 电源管理（TLP）
    ../modules/nixos/niri.nix   # 桌面：Niri + greetd + 终端 + 截图
  ];

  # 系统首次安装时的版本，决定有状态数据的默认格式。
  # 不是"当前版本"，升级 NixOS 时不要改它。
  system.stateVersion = "26.05";
}
