# Alacritty 终端：配色（Catppuccin Mocha）、字体、内边距、去掉自带标题栏。
# 由 home-manager 生成 ~/.config/alacritty/alacritty.toml（Alacritty 会自动热加载）。
#
# 注意：Noctalia 有个"应用主题模板"功能，会改写 Alacritty 的用户配置来同步配色。
# 这里已经由 home-manager 管理该文件（是 Nix store 里的只读链接），所以不要开启
# Noctalia 的 Alacritty 模板，否则两边会冲突。代价：Noctalia 切换浅色模式时，
# 终端配色不会跟着变，始终是深色 Mocha
{ ... }:
{
  programs.alacritty = {
    enable = true;

    settings = {
      # 字体：Nerd Font 带 Starship 提示符、终端程序要用的图标字形（见 modules/nixos/fonts.nix）。
      # 字号受屏幕缩放（1.75）影响，Alacritty 会自动按缩放换算，12 在这块屏上大小合适
      font = {
        normal.family = "CaskaydiaCove Nerd Font";
        size = 12;
      };

      window = {
        # 去掉 Alacritty 在 Wayland 下自带的备用标题栏：窗口只剩圆角、阴影和聚焦环，
        # 和 Niri 的 prefer-no-csd 方向一致。没有标题栏后用快捷键关闭（Mod+Q）
        decorations = "None";
        padding = {
          x = 10;
          y = 10;
        };
        dynamic_padding = true;
      };

      # Catppuccin Mocha：与 Noctalia 的 Catppuccin 深色主题保持一致
      colors = {
        primary = {
          background = "#1e1e2e";
          foreground = "#cdd6f4";
          dim_foreground = "#7f849c";
          bright_foreground = "#cdd6f4";
        };
        cursor = {
          text = "#1e1e2e";
          cursor = "#f5e0dc";
        };
        vi_mode_cursor = {
          text = "#1e1e2e";
          cursor = "#b4befe";
        };
        selection = {
          text = "#1e1e2e";
          background = "#f5e0dc";
        };
        search = {
          matches = {
            foreground = "#1e1e2e";
            background = "#a6adc8";
          };
          focused_match = {
            foreground = "#1e1e2e";
            background = "#a6e3a1";
          };
        };
        footer_bar = {
          foreground = "#1e1e2e";
          background = "#a6adc8";
        };
        hints = {
          start = {
            foreground = "#1e1e2e";
            background = "#f9e2af";
          };
          end = {
            foreground = "#1e1e2e";
            background = "#a6adc8";
          };
        };
        normal = {
          black = "#45475a";
          red = "#f38ba8";
          green = "#a6e3a1";
          yellow = "#f9e2af";
          blue = "#89b4fa";
          magenta = "#f5c2e7";
          cyan = "#94e2d5";
          white = "#bac2de";
        };
        bright = {
          black = "#585b70";
          red = "#f38ba8";
          green = "#a6e3a1";
          yellow = "#f9e2af";
          blue = "#89b4fa";
          magenta = "#f5c2e7";
          cyan = "#94e2d5";
          white = "#a6adc8";
        };
        indexed_colors = [
          { index = 16; color = "#fab387"; }
          { index = 17; color = "#f5e0dc"; }
        ];
      };
    };
  };
}
