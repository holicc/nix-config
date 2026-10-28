# home/

用户 `joe` 的 home-manager 配置。`flake.nix` 以 NixOS 模块方式集成它，所以 `switch` 会同时应用系统和用户配置，不需要单独的 `home-manager switch`。

| 路径 | 作用 |
|---|---|
| `default.nix` | 用户名、家目录、`home.stateVersion`，并 import 下面两个子目录 |
| `niri/` | 窗口管理器 Niri 的配置 |
| `noctalia/default.nix` | 桌面 Shell Noctalia v5 的全部设置 |

## niri/

nixpkgs 版的 niri 没有 home-manager 选项，所以直接生成 `~/.config/niri/config.kdl`。
配置按职责拆成独立的 `.kdl` 文件（有语法高亮），`default.nix` 用 `readFile` 按顺序拼接：

| 文件 | 内容 |
|---|---|
| `general.kdl` | 启动 Noctalia、请求去掉窗口标题栏（`prefer-no-csd`）、杂项 |
| `layout.kdl` | 窗口间距、聚焦环（淡紫色细边）、阴影 |
| `windowrules.kdl` | 窗口圆角、Noctalia 设置窗口的尺寸 |
| `input.kdl` | 触摸板：轻点即单击、自然滚动、打字时禁用 |
| `keybindings.kdl` | 全部快捷键，以官方默认为基础，启动器/截图/音量亮度换成 Noctalia 的命令 |

- 修改后先 `./scripts/nixos.sh check`，它会用 `niri validate` 校验生成的 KDL。
- Niri 26.04 比官方 main 分支旧，有些动作和语法不支持，校验会指出。
- 新增 `.kdl` 文件要加进 `niri/default.nix` 的 `parts` 列表，并 `git add`。
- `Mod+Shift+/` 可在运行中的桌面上查看当前生效的完整快捷键。

## noctalia/

`programs.noctalia.settings` 会写成 TOML 到 `~/.config/noctalia/config.toml`。
在 Noctalia 设置界面里改的内容保存在 `~/.local/state/noctalia/`，**优先级更高**，会覆盖这里的同名设置。

- 想让某项设置以这里为准，就别在界面里改它。
- 选项名可能随上游变化，报错先查 docs.noctalia.dev。
- 电池显示依赖系统层的 UPower（`modules/nixos/power.nix`），字体依赖 `modules/nixos/fonts.nix`。
