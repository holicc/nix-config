# nixos-config

`nixos-dev` 这台笔记本（NixOS 26.05，Ryzen 4000，AMD 核显）的 flake 配置。
桌面：Niri（Wayland 合成器）+ Noctalia v5（桌面 Shell）+ greetd/tuigreet 登录，**续航优先**。

## 目录结构

```
nixos-config/
├── flake.nix                  入口：inputs、nixosConfigurations.nixos-dev、home-manager 集成
├── flake.lock
├── nixos/                     系统入口：configuration.nix + hardware-configuration.nix
├── modules/nixos/             系统级模块：base、power、niri、fonts
├── home/                      用户级（home-manager）：default.nix + niri/ + noctalia/
├── scripts/nixos.sh           维护脚本（构建、校验、对比、清理等）
└── examples/rust-flake-template/   Rust 项目的 nix develop 模板（不属于系统配置）
```

每个目录有自己的 `README.md`，说明里面每个文件的作用。

## 日常使用

所有操作都通过脚本，它会自动带上本地 input 覆盖参数，并在构建前 `git add -A`：

```bash
./scripts/nixos.sh check     # 只校验，不构建（改完配置先跑这个）
./scripts/nixos.sh diff      # 构建并对比软件包差异，无输出 = 包没变
./scripts/nixos.sh switch    # 校验后切换系统（需要 sudo 密码）
./scripts/nixos.sh help      # 全部命令
```

建议的流程：改配置，`check`，`diff`，确认无误后 `switch`，最后 `git commit`。

## 为什么要本地 input（重要）

这台机器访问 GitHub 很慢，所以 `nixpkgs` 和 `noctalia` 的源码预先下载到 `~/nix-inputs/`：

```
~/nix-inputs/nixpkgs     nixpkgs 源码快照
~/nix-inputs/noctalia    Noctalia v5 源码（是一个 git 仓库，因为它的 flake 需要 git 版本号）
```

构建时用 `--override-input` 指向它们，`flake.lock` 里没有记录这两个本地路径。因此：

- **不要删除 `~/nix-inputs/`**，否则下一次构建会失败，或回退去 GitHub 下载并可能版本不匹配。
- **直接敲 `nix flake show`、`nixos-rebuild` 等命令会联网下载**，请用 `./scripts/nixos.sh`，或手动带上脚本里的 `OVERRIDES` 参数。
- 当前系统和旧版本不依赖这些目录（源码已复制进 `/nix/store`），只是影响"再次构建"。

## 软件与服务

| 类别 | 内容 |
|---|---|
| 桌面 | Niri 26.04、Noctalia 5.4（Shell）、greetd + tuigreet、alacritty、grim + slurp |
| 电源 | TLP（`power-profiles-daemon` 必须关闭，两者互斥）、UPower（电池显示） |
| 连接 | NetworkManager、BlueZ（蓝牙，开机默认不上电以省电）、OpenSSH |
| 字体 | CaskaydiaCove Nerd Font、Noto CJK 中文 |
| 开发 | Rust 走项目级 `nix develop`，**不在系统全局安装**，模板见 `examples/rust-flake-template/flake.nix` |

## 注意事项（踩过的坑）

- **flake 只识别 git 已 track 的文件**：新增文件后要 `git add`（脚本会自动做）。
- **`system.stateVersion` 保持 `"26.05"`**，不要因为升级 NixOS 版本而改动；`home.stateVersion` 同理。
- **`/boot` 的挂载选项（`fmask=0077,dmask=0077`）改动后必须整机重启才生效**，`switch` 不会让 vfat 的选项真正生效。
- **不要在 Live 安装环境里执行 `nixos-rebuild`**，那改的是 Live 环境自己，不会影响硬盘里的系统。
- **Niri 26.04 比官方 main 分支的默认配置旧**：有些动作和语法（如 `toggle-touchpad`、单按 Mod 切总览）不支持，改快捷键后用 `check` 校验。
- **Noctalia 选项名可能随上游变化**：v5 是 `programs.noctalia`，旧的 legacy-v4 分支是 `programs.noctalia-shell`。遇到 rebuild 报错先查 docs.noctalia.dev。
- **没有自动挂起**：这台机器靠 SSH 管理，挂起会断开 SSH，所以空闲只锁屏和关屏。

## 回滚

每次 `switch` 都会生成新的系统版本，旧版本保留：

- 开机时在 systemd-boot 菜单里选上一个版本；
- 或 `sudo nixos-rebuild switch --rollback`；
- `./scripts/nixos.sh gens` 查看全部版本，`./scripts/nixos.sh gc` 清理 7 天前的旧版本（清理后无法回滚到它们）。

## 参考

- [ryan4yin/nix-config](https://github.com/ryan4yin/nix-config)：目录结构、Noctalia 和 Niri 配置的主要参考
- Noctalia 文档：docs.noctalia.dev
- Niri 文档：yalter.github.io/niri
