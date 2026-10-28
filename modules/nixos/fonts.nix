# 字体：系统级安装，所有用户和程序可用
{ pkgs, ... }:
{
  # fonts.packages 里的字体会被 fontconfig 收录，Noctalia 通过字体名使用它们。
  # 排查方向：`fc-list | grep -i caskaydia` 查看实际的字体名称
  fonts.packages = with pkgs; [
    # CaskaydiaCove Nerd Font：微软 Cascadia Code 的 Nerd Fonts 版本，
    # 等宽、带编程连字和大量图标字形（状态栏、终端图标依赖 Nerd 字形）。
    # 选 nixpkgs 里的包而不是手动放字体文件，这样由配置管理、可复现。
    nerd-fonts.caskaydia-cove

    # Noto 无衬线中文字体：Nerd Fonts 不含中文，装它让中文显示统一、不依赖回退。
    noto-fonts-cjk-sans
  ];
}
