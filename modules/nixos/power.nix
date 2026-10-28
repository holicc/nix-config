# 电源管理
{ ... }:
{
  # TLP：笔记本续航优化。选它是因为开箱即用的默认策略就偏省电，
  # 且适合 Ryzen 4000 这类老一点的 AMD 平台。
  # 排查方向：`sudo tlp-stat -s` 查看状态
  services.tlp.enable = true;

  # power-profiles-daemon 与 TLP 互斥，必须关闭，否则会冲突报错
  services.power-profiles-daemon.enable = false;
}
