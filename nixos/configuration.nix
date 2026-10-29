# 系统主配置：只负责引入各子模块，具体内容拆分在 nixos/modules/ 下
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

    ./modules/base.nix   # 主机名/时区/引导/SSH/用户/全局工具
    ./modules/power.nix  # 电源管理（TLP）
    ./modules/niri.nix   # 桌面：Niri + greetd + 终端 + 截图
    ./modules/fonts.nix  # 字体：Nerd Font + 中文
    ./modules/browser.nix # 浏览器：Google Chrome（unfree，需代理预下载）
    ./modules/nix-ld.nix # 运行预编译二进制（rustup 下载的 Rust 工具链需要）
    ./modules/mihomo.nix # 代理：mihomo（Clash 内核），按需启动，nix/git 访问 GitHub 用
  ];

  # 系统首次安装时的版本，决定有状态数据的默认格式。
  # 不是"当前版本"，升级 NixOS 时不要改它。
  system.stateVersion = "26.05";
}
