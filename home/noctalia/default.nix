# Noctalia v5 桌面 Shell 的设置（状态栏 / 通知 / 启动器 / 锁屏 / 主题等）
{ inputs, ... }:
{
  # Noctalia v5 的 home-manager 模块来自 flake input（main 分支）。
  # v5 选项名是 programs.noctalia（旧的 legacy-v4 分支是 programs.noctalia-shell）。
  # 此选项名可能随上游更新变化，如遇报错请查阅 docs.noctalia.dev
  imports = [ inputs.noctalia.homeModules.default ];

  # 电池组件已在 v5 默认状态栏里，前提是系统层开启 UPower（见 modules/nixos/power.nix）。
  # 此选项名可能随上游更新变化，如遇报错请查阅 docs.noctalia.dev
  programs.noctalia = {
    enable = true;

    # 配置会写成 TOML；界面里改的设置保存在 ~/.local/state/noctalia/，优先级更高。
    # 借鉴自 ryan4yin/nix-config 的写法，只取通用项。
    settings = {
      # 关闭首次启动向导：该向导（含隐私弹窗）会卡住启动，声明式部署不需要它
      shell.setup_wizard_enabled = false;

      # 界面字体：需要系统已安装该字体（见 modules/nixos/fonts.nix），否则回退为默认字体。
      # 字体名以 `fc-list` 查到的为准
      shell.font_family = "CaskaydiaCove Nerd Font";

      # 通知和 OSD 放右下角，避开顶部状态栏
      osd.position = "bottom_right";
      notification.position = "bottom_right";

      # 启动器布局：simple = 顶部搜索框 + 分类标签 + 结果列表（固定 560x500），
      # 类似 Spotlight/Raycast；默认的 full 带最近/固定/全部/分类多个视图。
      # ryan4yin 没有自定义启动器，用的是默认值，这一项是我们自己的选择
      shell.launcher.layout = "simple";

      # 截图：框选区域后打开 Noctalia 自带的标注编辑器（替代 grim/slurp 的纯截图），
      # 保存到 ~/Pictures/Screenshots。对应快捷键见 ../niri/keybindings.kdl 的 Mod+Shift+S
      shell.screenshot = {
        annotate = true;
        directory = "~/Pictures/Screenshots";
      };

      # 电源菜单：指定动作列表会替换内置默认，所以 5 个动作要全部写出。
      # 除锁屏外都有 10 秒确认倒计时：第一次按下开始倒计时，再按立即执行，Esc 取消，防止误按关机。
      # 借鉴自 ryan4yin/nix-config
      shell.session.actions = [
        { action = "lock"; shortcut = "1"; }
        { action = "logout"; shortcut = "2"; countdown_seconds = 10; }
        { action = "lock_and_suspend"; shortcut = "3"; countdown_seconds = 10; }
        { action = "reboot"; shortcut = "4"; countdown_seconds = 10; }
        { action = "shutdown"; shortcut = "5"; variant = "destructive"; countdown_seconds = 10; }
      ];

      # 面板整体放大 10%，适合 2560x1600 高分屏
      accessibility.ui_scale = 1.1;

      # 夜间护眼：日落后自动把屏幕色温调暖（白天 6500K、夜晚 4000K），按下面的位置计算日落
      nightlight.enabled = true;

      # 壁纸目录：启动器 /wall 和状态栏壁纸图标从这里读取图片
      wallpaper.directory = "/home/joe/Pictures/Wallpapers";

      # 空闲管理：10 分钟无操作锁屏，11 分钟关闭屏幕（续航）。
      # 刻意不开自动挂起：这台机器靠 SSH 管理，挂起会让 SSH 断开。
      # 锁屏走 PAM 的 login 服务，已确认 /etc/pam.d/login 存在
      idle.behavior.lock = {
        timeout = 600;
        action = "lock";
        enabled = true;
      };
      idle.behavior."screen-off" = {
        timeout = 660;
        action = "screen_off";
        enabled = true;
      };

      # 低电量提醒：20% 就提醒（默认 10%），5% 仍有严重警告
      battery.warning_threshold = 20;

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
}
