# joe 用户级配置：Niri 个人配置（快捷键等）+ Noctalia 设置
{ inputs, ... }:
{
  # Noctalia 的 home-manager 模块来自 flake input。
  # 此选项/模块名可能随上游更新变化，如遇报错请查阅 docs.noctalia.dev
  # （曾有升级后 programs.noctalia-shell / programs.noctalia 不一致的反馈）
  imports = [ inputs.noctalia.homeModules.default ];

  home.username = "joe";
  home.homeDirectory = "/home/joe";

  # 用户级 stateVersion，同样不要随升级改动
  home.stateVersion = "26.05";

  # Noctalia 桌面 Shell（状态栏/通知/启动器等）。
  # 此选项名可能随上游更新变化，如遇报错请查阅 docs.noctalia.dev
  programs.noctalia-shell.enable = true;
  programs.noctalia-shell.settings = {
    # 按需填写，具体键名以官方文档为准
  };

  # Niri 个人配置：nixpkgs 版 niri 没有 home-manager 选项，
  # 直接写 KDL 配置文件，简单且无额外依赖。
  # 排查方向：`niri validate` 检查语法
  xdg.configFile."niri/config.kdl".text = ''
    // 启动时拉起 Noctalia；命令名以上游文档为准（可能是 noctalia-shell）
    spawn-at-startup "noctalia-shell"

    binds {
        Mod+Return { spawn "alacritty"; }
        Mod+Q { close-window; }
        Mod+Tab { toggle-overview; }          // Overview 需 niri ≥25.05
        Mod+Left  { focus-column-left; }
        Mod+Right { focus-column-right; }
        Mod+Shift+S { spawn "sh" "-c" "grim -g \"$(slurp)\" ~/screenshot-$(date +%s).png"; }
        Mod+Shift+E { quit; }
    }
  '';

  programs.home-manager.enable = true;
}
