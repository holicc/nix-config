# joe 用户级配置：Niri 个人配置（快捷键等）+ Noctalia v5 设置
{ inputs, ... }:
{
  # Noctalia v5 的 home-manager 模块来自 flake input（main 分支）。
  # v5 选项名是 programs.noctalia（旧的 legacy-v4 分支是 programs.noctalia-shell）。
  # 此选项名可能随上游更新变化，如遇报错请查阅 docs.noctalia.dev
  imports = [ inputs.noctalia.homeModules.default ];

  home.username = "joe";
  home.homeDirectory = "/home/joe";

  # 用户级 stateVersion，同样不要随升级改动
  home.stateVersion = "26.05";

  # Noctalia 桌面 Shell（状态栏/通知/启动器等）。
  # 电池组件已在 v5 默认状态栏里，前提是系统层开启 UPower（见 modules/nixos/power.nix）。
  # 此选项名可能随上游更新变化，如遇报错请查阅 docs.noctalia.dev
  programs.noctalia = {
    enable = true;

    # 配置会写成 TOML；界面里改的设置保存在 ~/.local/state/noctalia/，优先级更高。
    # 借鉴自 ryan4yin/nix-config 的写法，只取通用项。
    settings = {
      # 关闭首次启动向导：该向导（含隐私弹窗）会卡住启动，声明式部署不需要它
      shell.setup_wizard_enabled = false;

      # 通知和 OSD 放右下角，避开顶部状态栏
      osd.position = "bottom_right";
      notification.position = "bottom_right";

      # 面板整体放大 10%，适合 2560x1600 高分屏
      accessibility.ui_scale = 1.1;

      # 位置：用于按日出日落自动切换深浅色（以及天气）。
      # 若解析不出位置，改成更常见的写法如 "Luzhou"，或查阅 docs.noctalia.dev
      location.address = "Luzhou, Sichuan, China";

      # 主题：内置 Catppuccin 配色，mode = "auto" 按上面位置的日出日落切换深浅色
      theme = {
        source = "builtin";
        builtin = "Catppuccin";
        mode = "auto";
      };

      # 状态栏：半透明、文字略大、两端留白更宽（让居中的时钟不被挤占）
      bar.main = {
        background_opacity = 0.61;
        font_scale = 1.1;
        margin_ends = 20;
        # 在默认的左侧区域后追加 CPU/内存/磁盘/网速监控
        start = [ "launcher" "wallpaper" "workspaces" "cpu" "ram" "disk" "net_rx" "net_tx" ];
      };

      # 时钟：年-月-日 星期 时:分
      widget.clock = {
        type = "clock";
        format = "{:%Y-%m-%d %A %H:%M}";
      };

      # 系统监控组件（借鉴 ryan4yin/nix-config，磁盘改为监控 /）
      widget.cpu = { type = "sysmon"; stat = "cpu_usage"; };
      widget.ram = { type = "sysmon"; stat = "ram_pct"; };
      widget.disk = { type = "sysmon"; stat = "disk_used_pct"; path = "/"; };
      # 网速用紧凑单位（如 1.2M），保持宽度稳定
      widget.net_rx = { type = "sysmon"; stat = "net_rx"; network_speed_compact = true; };
      widget.net_tx = { type = "sysmon"; stat = "net_tx"; network_speed_compact = true; };

      # 网络：只显示状态图标，不显示 SSID（太长），悬停仍可看完整名称
      widget.network.show_label = false;

      # 媒体：没有播放时隐藏，不显示 "Nothing Playing" 占位
      widget.media.hide_when_no_media = true;
    };
  };

  # Niri 个人配置：nixpkgs 版 niri 没有 home-manager 选项，直接写 KDL。
  # 其中 Noctalia 相关规则参考官方文档 docs.noctalia.dev/noctalia/compositor-settings/niri/
  # 排查方向：`niri validate` 检查语法
  xdg.configFile."niri/config.kdl".text = ''
    // 启动 Noctalia v5（二进制名是 noctalia）
    spawn-at-startup "noctalia"

    // 窗口圆角并裁剪内容，与 Noctalia 风格一致
    window-rule {
        geometry-corner-radius 20
        clip-to-geometry true
    }

    // Noctalia 设置窗口以浮动方式打开
    window-rule {
        match app-id="dev.noctalia.Noctalia"
        open-floating true
        default-column-width { fixed 1080; }
        default-window-height { fixed 920; }
    }

    // 允许 Noctalia 的通知操作和窗口激活
    debug {
        honor-xdg-activation-with-invalid-serial
    }

    binds {
        Mod+Return { spawn "alacritty"; }
        Mod+Q { close-window; }
        Mod+Tab { toggle-overview; }          // Overview 需 niri >=25.05
        Mod+Left  { focus-column-left; }
        Mod+Right { focus-column-right; }
        Mod+Shift+S { spawn "sh" "-c" "grim -g \"$(slurp)\" ~/screenshot-$(date +%s).png"; }
        Mod+Shift+E { quit; }

        // Noctalia：启动器、控制中心、设置
        Mod+Space { spawn-sh "noctalia msg panel-toggle launcher"; }
        Mod+S { spawn-sh "noctalia msg panel-toggle control-center"; }
        Mod+Shift+Comma { spawn-sh "noctalia msg settings-toggle"; }

        // 音量与亮度（由 Noctalia 处理并显示 OSD）
        XF86AudioRaiseVolume { spawn-sh "noctalia msg volume-up"; }
        XF86AudioLowerVolume { spawn-sh "noctalia msg volume-down"; }
        XF86AudioMute { spawn-sh "noctalia msg volume-mute"; }
        XF86MonBrightnessUp { spawn-sh "noctalia msg brightness-up"; }
        XF86MonBrightnessDown { spawn-sh "noctalia msg brightness-down"; }
    }
  '';

  programs.home-manager.enable = true;
}
