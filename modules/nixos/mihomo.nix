# 代理：mihomo（Clash.Meta 内核），主要给 nix 和 git 访问 GitHub 用，也可按需开透明代理（TUN）。
# 不装 webui：用 `./scripts/nixos.sh proxy ...` 管理，需要时通过 mihomo 的本地 API 切换 TUN。
{ lib, ... }:
{
  services.mihomo = {
    enable = true;

    # 配置文件里有订阅地址，属于敏感信息：放在仓库外面，这里只写路径，不进 GitHub。
    # 必须写成字符串，不能写成 Nix 路径字面量（/home/... 不带引号）：
    # 路径字面量会被复制进 /nix/store，那里所有用户可读，等于泄露订阅。
    # 首次使用：./scripts/nixos.sh proxy init，然后编辑该文件，填入订阅地址
    configFile = "/home/joe/.config/mihomo/config.yaml";

    # 只授予 TUN 所需的权限，TUN 是否开启由配置文件里的 tun.enable 决定
    # （模板里默认关闭，用 `./scripts/nixos.sh proxy tun on|off` 在运行时切换，不用重新构建）。
    # 排查方向：开启后用 `ip addr` 应能看到 Meta 网卡；权限不足时看 `journalctl -u mihomo`
    tunMode = true;
  };

  # 不随开机启动：续航优先，不用代理时完全不占资源。
  # 需要时 `./scripts/nixos.sh proxy on`，用完 `proxy off`
  systemd.services.mihomo.wantedBy = lib.mkForce [ ];
}
