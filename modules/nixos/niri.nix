# 图形桌面（系统层）：Niri + greetd/tuigreet + alacritty + grim/slurp
{ pkgs, ... }:
{
  # Niri：滚动平铺的 Wayland 合成器。
  # 选它：Wayland 原生、资源占用小，核显下更省电；
  # 需 ≥25.05 才有 Overview 功能（26.05 的 nixpkgs 满足）。
  # 排查方向：若版本不够，检查 nixpkgs 分支，或 `niri --version`
  programs.niri.enable = true;

  # greetd + tuigreet：纯文本终端登录管理器。
  # 选它：不依赖 GTK/Qt 图形栈，内存与耗电都比 GDM/SDDM 低。
  # 登录后通过 niri-session 启动 Niri。
  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --cmd niri-session";
      user = "greeter";
    };
  };

  # 系统级桌面工具
  environment.systemPackages = with pkgs; [
    # alacritty：GPU 加速终端，轻量、启动快，配置简单
    alacritty
    # grim：Wayland 截图；slurp：框选区域。两者小而专一，组合使用
    # 例：grim -g "$(slurp)" - | wl-copy （需另装 wl-clipboard）
    grim
    slurp
  ];
}
