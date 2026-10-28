# 代理：mihomo（Clash.Meta 内核），主要给 nix 和 git 访问 GitHub 用，也可按需开透明代理（TUN）。
# 不装 webui：用 `./scripts/nixos.sh proxy ...` 管理，需要时通过 mihomo 的本地 API 切换 TUN。
{ lib, pkgs, ... }:
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
  # 注意：光有这一项还不够，TCP 还需要下面的 trustedInterfaces，否则 DNS 好了但 HTTPS 连不上
  networking.firewall.checkReversePath = "loose";

  # 把 TUN 网卡设为受信任网卡，让 mixed / system 栈的 TCP 能通。
  # 证据：运行中防火墙的 INPUT 规则只放行回环、已建立连接、22 端口和 ping，其余一律拒绝，
  # 没有放行 Meta 的规则；mixed / system 栈会在 TUN 地址（198.18.0.1）上开 TCP 监听，
  # 数据包被改写后"进入本机"，是新连接，被最后一条规则丢弃，所以 curl 停在 Trying 然后超时，
  # mihomo 日志里也看不到这条连接。不依赖本机监听的 gvisor 栈则不受影响。
  # 验证：运行中的防火墙出现 `-A nixos-fw -i Meta -j nixos-fw-accept` 后，mixed 和 system 栈的
  # HTTPS 都恢复（HTTP 200）。
  # 安全性：TUN 的另一端就是 mihomo 自己，没有外部对端，信任它不会向外暴露端口。
  # 网卡名 Meta 是 mihomo 的默认值，基础设置里也显式写了 device: Meta，两边要保持一致
  networking.firewall.trustedInterfaces = [ "Meta" ];

  # 启动前把预先下载好的 geoip.metadb 复制进 mihomo 的状态目录。
  # 背景：订阅规则里的 GEOIP,CN 需要这个数据库，mihomo 启动时找不到会自己下载，而这台机器上
  # 下载很慢（实测 8.4MB 用了 51 秒），超过它的 90 秒超时就会 fatal 退出，服务整个起不来。
  # 所以由 `nx proxy init/update` 在用户态预先下载到 ~/.config/mihomo/geoip.metadb（超时宽松、可重试），
  # 这里在启动前复制过去。
  # ExecStartPre 的前缀：`-` 表示复制失败（比如文件还没下载）也不阻止启动，退回到 mihomo 自己下载；
  # `+` 表示以完整权限运行，不受该服务 ProtectHome 等沙箱限制（否则读不到 /home 下的文件）。
  # 排查方向：`journalctl -u mihomo -b` 里仍出现 "Can't find MMDB, start download"，
  # 说明复制没成功，检查 ~/.config/mihomo/geoip.metadb 是否存在
  systemd.services.mihomo.serviceConfig.ExecStartPre = [
    "-+${pkgs.coreutils}/bin/install -D -m 0644 /home/joe/.config/mihomo/geoip.metadb /var/lib/private/mihomo/geoip.metadb"
  ];

  # 不随开机启动：续航优先，不用代理时完全不占资源。
  # 需要时 `nx proxy on`，用完 `proxy off`
  systemd.services.mihomo.wantedBy = lib.mkForce [ ];
}
