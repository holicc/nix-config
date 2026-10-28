# 代理：mihomo（Clash.Meta 内核），主要给 nix 和 git 访问 GitHub 用，也可按需开透明代理（TUN）。
# 不装 webui：用 `./scripts/nixos.sh proxy ...` 管理，需要时通过 mihomo 的本地 API 切换 TUN。
{ lib, ... }:
{
  services.mihomo = {
    enable = true;

    # 配置文件里有订阅地址，属于敏感信息：放在仓库外面，这里只写路径，不进 GitHub。
    # 必须写成字符串，不能写成 Nix 路径字面量（/home/... 不带引号）：
    # 路径字面量会被复制进 /nix/store，那里所有用户可读，等于泄露订阅。
    # 首次使用：nx proxy init，按提示粘贴订阅地址，脚本会下载订阅并生成这个文件
    configFile = "/home/joe/.config/mihomo/config.yaml";

    # 只授予 TUN 所需的权限，TUN 是否开启由配置文件里的 tun.enable 决定
    # （基础设置里默认关闭，因为在这台机器上开启后系统 DNS 会失效、原因还在排查；
    # 用 `nx proxy tun on|off` 在运行时切换，不用重新构建）。
    # 排查方向：开启后用 `ip addr` 应能看到 Meta 网卡；权限不足时看 `journalctl -u mihomo`
    tunMode = true;
  };

  # 放宽防火墙的反向路径过滤，修复开启 TUN 后系统 DNS 全部失效的问题（已实测验证）。
  # 原因：NixOS 默认 checkReversePath = true（严格），会丢弃"从某个网卡进来、但按路由回复本该从
  # 另一个网卡出去"的包。TUN 开启后，DNS 应答和网页回包都从虚拟网卡 Meta 回来，来源地址
  # （如路由器）按路由却应走 Wi-Fi 网卡，于是被丢弃。
  # 验证：运行中的防火墙规则里是 `-m rpfilter --validmark`，改成 loose 后变成
  # `-m rpfilter --validmark --loose`，开 TUN 后 `getent hosts github.com` 立即恢复应答。
  # "loose" 只要求回复能从任意网卡出去，是 NixOS 上 Tailscale/WireGuard/Clash 类 TUN 工具的常规做法。
  # 代价：放宽了一项反 IP 欺骗检查，对笔记本日常使用影响很小。
  # 注意：光有这一项还不够，TUN 的栈要用 gvisor（见 examples/mihomo/config.example.yaml），
  # 默认的 mixed 栈在这台机器上 TCP 不通
  networking.firewall.checkReversePath = "loose";

  # 不随开机启动：续航优先，不用代理时完全不占资源。
  # 需要时 `nx proxy on`，用完 `proxy off`
  systemd.services.mihomo.wantedBy = lib.mkForce [ ];
}
