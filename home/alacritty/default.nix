# Alacritty 终端：字体、内边距、去掉自带标题栏。
# 配色由 home/theme（catppuccin/nix）提供，这里不再手写色值。
# 由 home-manager 生成 ~/.config/alacritty/alacritty.toml（Alacritty 会自动热加载）。
#
# 注意：Noctalia 有个"应用主题模板"功能，会改写 Alacritty 的用户配置来同步配色。
# 这里已经由 home-manager 管理该文件（是 Nix store 里的只读链接），所以不要开启
# Noctalia 的 Alacritty 模板，否则两边会冲突。代价：Noctalia 切换浅色模式时，
# 终端配色不会跟着变，始终是深色 Macchiato
{ ... }:
{
  programs.alacritty = {
    enable = true;

    settings = {
      # 字体：Nerd Font 带 Starship 提示符、终端程序要用的图标字形（见 nixos/modules/fonts.nix）。
      # 字号受屏幕缩放（1.75）影响，Alacritty 会自动按缩放换算，12 在这块屏上大小合适
      font = {
        normal.family = "CaskaydiaCove Nerd Font";
        size = 12;
      };

      # 终端里直接启动 Nushell（Starship 提示符只接在 Nushell 上）。
      # 登录 shell 和 SSH 仍是 bash，所以远程管理、脚本都不受影响；
      # 想回到 bash 就在终端里输入 `bash`。Nushell 出问题时，`alacritty -e bash` 也能临时打开 bash
      terminal.shell.program = "nu";

      # 鼠标右键 = 复制选中的文字。触摸板上双指轻点或双指按下就是右键（Niri 的 tap 设置），
      # 所以"选中文字后双指点一下"即复制。Alacritty 默认的右键是"扩展选区"，这里覆盖掉了它。
      # 粘贴：三指轻点（中键，粘贴最近选中的文字）或 Ctrl+Shift+V；
      # 键盘复制仍是 Ctrl+Shift+C，Ctrl+C 保持"中断命令"
      mouse.bindings = [
        {
          mouse = "Right";
          action = "Copy";
        }
      ];

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
    };
  };
}
