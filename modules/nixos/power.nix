# 电源管理
{ ... }:
{
  # TLP：笔记本续航优化。选它是因为开箱即用的默认策略就偏省电，
  # 且适合 Ryzen 4000 这类老一点的 AMD 平台。
  # 排查方向：`sudo tlp-stat -s` 查看状态
  services.tlp.enable = true;

  # power-profiles-daemon 与 TLP 互斥，必须关闭，否则会冲突报错
  services.power-profiles-daemon.enable = false;

  # UPower：向桌面 Shell 提供电池电量和充电状态，Noctalia 的电池组件依赖它。
  # 只做状态上报，不改变电源策略，不会和 TLP 冲突。
  # 排查方向：`upower -e` 应能列出电池设备
  services.upower.enable = true;
}
