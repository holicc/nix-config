# modules/

系统级（NixOS）模块，每个文件负责一类功能，由 `nixos/configuration.nix` 引入。

| 文件 | 内容 | 选择理由 |
|---|---|---|
| `nixos/base.nix` | 主机名、时区、启用 flakes、systemd-boot、`consoleLogLevel`、SSH、NetworkManager、蓝牙（BlueZ）、用户 `joe`、全局 git/curl | systemd-boot 比 GRUB 更轻；蓝牙开机默认不上电以省电；全局只放最小工具集 |
| `nixos/power.nix` | TLP、关闭 power-profiles-daemon、UPower | TLP 开箱即用的省电策略；两个电源守护进程互斥；UPower 给桌面提供电池电量 |
| `nixos/niri.nix` | Niri、greetd + tuigreet、alacritty、grim、slurp | Wayland 原生、占用小；tuigreet 是文本登录界面，不依赖 GTK/Qt，更省电 |
| `nixos/fonts.nix` | CaskaydiaCove Nerd Font、Noto CJK 中文 | Nerd Font 提供图标字形；Nerd Fonts 不含中文，所以补装 Noto |
| `nixos/mihomo.nix` | mihomo 代理服务（Clash 内核）：不随开机启动、授予 TUN 权限、配置文件放仓库外 | 访问 GitHub 慢，nix 和 git 需要代理；按需启动不占电；订阅地址是敏感信息，不进仓库；不装 webui，用脚本切换 TUN |

## 新增模块的步骤

1. 在 `nixos/` 下新建 `xxx.nix`，每个配置块前写清楚：做什么、为什么这样选、有无已知风险和排查方向。
2. 在 `../nixos/configuration.nix` 的 `imports` 里加一行。
3. `git add` 新文件（flake 只认已 track 的文件），然后 `./scripts/nixos.sh check`。
