# 基础系统配置：从原 /etc/nixos/configuration.nix 迁移而来
{ pkgs, ... }:
{
  # 主机名：与 flake.nix 中 nixosConfigurations.nixos-dev 保持一致
  networking.hostName = "nixos-dev";

  # 网络：NetworkManager，笔记本切换 Wi-Fi 最省心
  networking.networkmanager.enable = true;

  # 蓝牙：启用 BlueZ 服务，Noctalia 的蓝牙组件依赖它（否则日志报 BlueZ 注册失败）。
  # powerOnBoot = false：续航优先，开机默认不给蓝牙适配器上电，
  # 需要时在 Noctalia 的蓝牙组件或控制中心里手动打开。
  # 排查方向：`bluetoothctl show` 查看适配器状态，`rfkill list` 查看是否被屏蔽
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = false;

  # 时区
  time.timeZone = "Asia/Shanghai";

  # 启用 flakes 与新版 nix 命令（未启用则本仓库无法求值）
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # 二进制缓存：优先走 USTC 国内镜像加速下载预编译包，官方源兜底。
  # 注意：只加速二进制包，不影响 flake input（github 源码）的下载；
  # 后者下载失败需要走代理。排查方向：`nix store ping --store <url>`
  nix.settings.substituters = [
    "https://mirrors.ustc.edu.cn/nix-channels/store"
    "https://cache.nixos.org/"
  ];

  # 引导：UEFI + systemd-boot，比 GRUB 更轻、配置更少
  # 提示：/boot 的 fmask=0077,dmask=0077 在 hardware-configuration.nix 里；
  # 修改后需整机重启才会真正生效
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # 控制台只显示错误级别以上的内核日志（3 = error）。
  # 否则像 Wi-Fi 驱动 rtw88 的校准提示会直接打印在 tuigreet 登录界面上。
  # 排查方向：问题仍可用 `dmesg` 或 `journalctl -k` 查看，只是不再刷在屏幕上
  boot.consoleLogLevel = 3;

  # SSH：机器通过 SSH 远程管理，必须保持开启
  services.openssh.enable = true;

  # 用户 joe：wheel 可 sudo，networkmanager 可管理网络
  users.users.joe = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
    ];
  };

  # 全局基础工具：只放最小集合，其余按项目用 nix develop 或放用户级
  environment.systemPackages = with pkgs; [
    git
    curl
  ];
}
