# 网络调试类工具。
{ pkgs, ... }:
{
  home.packages = [
    pkgs.dnsutils # dig、nslookup：查 DNS 解析
  ];
}
