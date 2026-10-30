# Neomacs：用 Rust 重写的 Emacs（GPU 渲染，兼容 Elisp），项目还在早期（0.0.x）。
# 来自它自己的 flake（inputs.neomacs），不走 nixpkgs；命令是 neomacs 和 neomacsclient，
# 同时会提供 emacs、emacsclient 两个同名入口（本机没有别的 Emacs，不冲突；以后装了原版要处理）。
# 升级：nx update neomacs。
# 缓存：它的 flake 声明了两个 Cachix 缓存（eval-exec 和 nix-wpe-webkit），但这里没有信任它们
# （nix 的 trusted-users 只有 root，flake 里的缓存设置对我们的系统构建不生效）。
# 所以升级版本后需要在本机重新编译，最后一步（LTO）单线程，要几十分钟；
# 想省时间：先 `sudo nix build github:eval-exec/neomacs#neomacs --accept-flake-config`，
# 让 root 用缓存构建好，再 nx switch 就直接命中。
# 排查方向：中文输入靠 Wayland 的 text-input 协议（fcitx5 已开 waylandFrontend）；字体默认回退到 DejaVu，
# 想用 CaskaydiaCove Nerd Font 要在 Neomacs 里设置。
{ inputs, pkgs, ... }:
{
  home.packages = [ inputs.neomacs.packages.${pkgs.stdenv.hostPlatform.system}.neomacs ];
}
