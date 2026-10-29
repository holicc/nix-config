# 中文输入法：Fcitx5 + 拼音。
# waylandFrontend = true：在 Wayland（Niri）下通过 text-input 协议和程序通信，
# 此时 NixOS 不再设置 GTK_IM_MODULE / QT_IM_MODULE，避免和 Wayland 原生输入冲突。
# 切换中英文：Ctrl+空格（Fcitx5 默认）。
# 排查方向：某个程序里打不出中文，先看它是不是 Wayland 原生程序；
# Chrome 需要额外参数（见 browser.nix 的 commandLineArgs）；
# `fcitx5-diagnose` 会列出环境变量和模块加载情况。
{ pkgs, ... }:
let
  # 候选面板主题：形状仿 macOS（横排、圆角面板，选中的候选是直角色块），配色用 Catppuccin Macchiato，
  # 和桌面的聚焦环、状态栏一致。Fcitx5 的主题就是一份 theme.conf 加两张图：
  # 面板是 svg，按"九宫格"拉伸，四个角保持原样，所以圆角半径不能大于对应的 Margin。
  # 想换色：改下面的色值（Macchiato：base #24273a、surface0 #363a4f、surface2 #5b6078、
  # text #cad3f5、mauve #c6a0f6；高亮想要 macOS 的蓝色就把 mauve 换成 blue #8aadf4）。
  # 想调大小：改 Font 的字号；想调圆角：同时改 svg 的 rx 和对应的 Margin。
  # 局限：候选前的序号和候选文字同样大，Fcitx5 主题不能单独设序号的大小和颜色；
  # macOS 右侧的"展开"小箭头也没有。
  themeName = "macos-catppuccin";
  theme = pkgs.runCommand "fcitx5-theme-${themeName}" { } ''
    d=$out/share/fcitx5/themes/${themeName}
    mkdir -p $d

    # 面板：深色底加一圈细边，圆角 14
    cat > $d/panel.svg <<'SVG'
    <svg width="48" height="48" version="1.1" xmlns="http://www.w3.org/2000/svg">
      <rect x="0.5" y="0.5" width="47" height="47" rx="13.5" fill="#363a4f" stroke="#5b6078"/>
    </svg>
    SVG

    cat > $d/theme.conf <<'CONF'
    [Metadata]
    Name=macOS style, Catppuccin Macchiato
    Version=1.0
    Description=Rounded horizontal candidate bar like macOS, Catppuccin Macchiato colors
    ScaleWithDPI=True

    [InputPanel]
    Font=Sans 14
    Spacing=6
    # 普通候选的文字色（Text）
    NormalColor=#cad3f5
    # 选中候选的文字色（Base，压在紫色高亮上）
    HighlightCandidateColor=#24273a
    # 正在输入的拼音的高亮色（Mauve）和它的背景（Surface 0）
    HighlightColor=#c6a0f6
    HighlightBackgroundColor=#363a4f

    [InputPanel/TextMargin]
    Left=14
    Right=14
    Top=6
    Bottom=6

    [InputPanel/Background]
    Image=panel.svg

    [InputPanel/Background/Margin]
    Left=14
    Right=14
    Top=14
    Bottom=14

    [InputPanel/Highlight]
    # 选中的候选：纯色直角块（不用图片就是直角；想要圆角就换成 Image=highlight.svg 并提供圆角 svg）
    Color=#c6a0f6

    [InputPanel/Highlight/Margin]
    Left=14
    Right=14
    Top=8
    Bottom=8
    CONF
  '';
in
{
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5 = {
      waylandFrontend = true;
      addons = [
        # 拼音引擎（含云拼音、符号表情等）
        pkgs.qt6Packages.fcitx5-chinese-addons
        # GTK 程序的输入法模块
        pkgs.fcitx5-gtk
        # 候选面板主题（见上面的 theme）
        theme
      ];
      # 候选面板（Fcitx5 的 classicui）：用上面的主题，横排。
      # DarkTheme：系统切到深色时用的主题，也指向同一个，避免被换成默认主题
      settings.addons.classicui.globalSection = {
        Theme = themeName;
        DarkTheme = themeName;
        "Vertical Candidate List" = "False";
      };
      # 声明式的输入法组：默认英文键盘加拼音，开机即可用，不必先打开图形配置界面
      settings.inputMethod = {
        GroupOrder."0" = "Default";
        "Groups/0" = {
          Name = "Default";
          "Default Layout" = "us";
          DefaultIM = "pinyin";
        };
        "Groups/0/Items/0".Name = "keyboard-us";
        "Groups/0/Items/1".Name = "pinyin";
      };
    };
  };
}
