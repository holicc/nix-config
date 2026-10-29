# 统一配色：Catppuccin（catppuccin/nix），参考 ryan4yin/nix-config 的 home/base/core/theme.nix。
# 一处声明风味和强调色，home-manager 里支持的程序（Alacritty、btop、fzf、lazygit 等）
# 自动套用同一套配色，不用再逐个手写色值。
# 排查方向：想知道某个程序有没有被套上，看 `nx pkgs` 里是否有它，再查
# https://nix.catppuccin.com 的支持列表；某程序不想用，设 catppuccin.<程序名>.enable = false
{ inputs, ... }:
{
  imports = [ inputs.catppuccin.homeModules.catppuccin ];

  catppuccin = {
    enable = true; # 所有支持的程序默认开启
    autoEnable = true; # 新版要求和 enable 同时写，否则 check 会给出警告
    flavor = "latte"; # latte（浅色）/ frappe / macchiato / mocha（深色）
    accent = "mauve"; # 和 Niri 聚焦环（#8839ef）同一个紫色

    # Starship 用 home/shell 里手写的两行布局和调色板，不让 catppuccin 的端口覆盖
    starship.enable = false;
  };
}
