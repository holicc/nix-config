# Niri 个人配置：nixpkgs 版 niri 没有 home-manager 选项，所以直接生成 KDL 配置文件。
# 配置按职责拆成几个 .kdl 文件（有语法高亮、注释清晰），这里按顺序拼成 ~/.config/niri/config.kdl。
# Noctalia 相关规则参考官方文档 docs.noctalia.dev/noctalia/compositor-settings/niri/
# 排查方向：`niri validate` 检查语法；`./scripts/nixos.sh check` 会在切换前校验生成的 KDL。
# 注意：新增 .kdl 文件后要 `git add`，flake 只认 git 已 track 的文件
{ lib, ... }:
let
  # 拼装顺序即配置文件里的先后顺序
  parts = [
    ./general.kdl      # 启动项、去标题栏、杂项
    ./layout.kdl       # 窗口间距、聚焦环、阴影
    ./windowrules.kdl  # 窗口规则：圆角、Noctalia 设置窗口
    ./input.kdl        # 触摸板
    ./keybindings.kdl  # 快捷键
  ];
in
{
  xdg.configFile."niri/config.kdl".text = lib.concatMapStringsSep "\n" builtins.readFile parts;
}
