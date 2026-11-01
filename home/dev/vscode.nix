# VS Code（闭源，unfree；放行名单在 nixos/modules/browser.nix 的 allowUnfreePredicate 里）。
# --ozone-platform-hint=auto：Wayland（Niri）下用原生 Wayland，不模糊；
# --enable-wayland-ime 和 --wayland-text-input-version=3：让 Fcitx5 能在里面打中文。
# 排查方向：打不出中文，先确认这两个参数在生效（code --version 不会报错，但看 ps 里的启动参数）。
{ pkgs, ... }:
{
  home.packages = [
    (pkgs.vscode.override {
      commandLineArgs = "--ozone-platform-hint=auto --enable-wayland-ime --wayland-text-input-version=3";
    })
  ];
}
