# 浏览器：Google Chrome（闭源，nixpkgs 里是 unfree 包，需要显式放行）。
# 不放行所有 unfree，只放行名单里的包，以后装别的闭源软件要在这里加名字。
#
# 注意：Chrome 安装包来自 dl.google.com，由 nix-daemon 下载，而 daemon 不走你 shell 里的代理变量。
# 这台机器直连 dl.google.com 不通，所以首次安装或升级版本前要先用代理预下载进 store：
#   https_proxy=http://127.0.0.1:7890 nix-prefetch-url <安装包地址> --name <文件名>
# 具体命令见 modules/README.md 的 browser.nix 一行。
# 排查方向：build 报 "unable to download ... dl.google.com" 说明这一步没做，
# 或者 nixpkgs 升级后 Chrome 版本变了（nixpkgs 钉死具体版本，Google 只保留较新的几个版本）
{ lib, pkgs, ... }:
{
  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [ "google-chrome" ];

  environment.systemPackages = [
    # --ozone-platform-hint=auto：在 Wayland（Niri）下用原生 Wayland 而不是 XWayland，
    # 缩放清晰、不模糊
    (pkgs.google-chrome.override { commandLineArgs = "--ozone-platform-hint=auto"; })
  ];
}
