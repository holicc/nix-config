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
└── examples/                  rust-flake-template（Rust 的 nix develop 模板）、mihomo（代理配置模板，不含订阅）
```

每个目录有自己的 `README.md`，说明里面每个文件的作用。

## 日常使用

所有操作都通过脚本，它会自动处理 input 的来源（见下面"软件版本和 flake.lock"），并在构建前 `git add -A`。
脚本通过 home-manager 装成了 `nx` 命令（见 `home/default.nix`），**在任何目录都能直接用**；
也可以在仓库里用 `./scripts/nixos.sh` 代替 `nx`，两者完全等价：

```bash
nx check     # 只校验，不构建（改完配置先跑这个）
nx diff      # 构建并对比软件包差异，无输出 = 包没变
nx switch    # 校验后切换系统（需要 sudo 密码）
nx help      # 全部命令
```

首次装上 `nx` 之前（还没 switch 过），请先用 `./scripts/nixos.sh switch`。

建议的流程：改配置，`check`，`diff`，确认无误后 `switch`，最后 `git commit`。

## 软件版本和 flake.lock（重要）

`nixpkgs`、`home-manager`、`noctalia` 这三个 input 的版本由 `flake.lock` 固定。脚本按锁的内容自动判断处于哪种模式：

| 模式 | 判断依据 | 行为 |
|---|---|---|
| **正式模式** | `flake.lock` 里有 `noctalia`（说明已用 `nx update` 生成过真正的锁） | 三个 input 固定到 GitHub 上的具体版本，不需要任何覆盖参数，也不需要本地源码副本 |
| **过渡模式** | 锁还是模板自带的旧锁（没有 `noctalia`） | 这台机器直连 GitHub 很慢，所以用 `~/nix-inputs/` 里预先下载的源码副本做 `--override-input`，避免现下载 |

**升级软件版本**（GitHub 直连很慢，建议先 `nx proxy on`，并给命令带上 `https_proxy=http://127.0.0.1:7890`；`nx update` 本身不碰代理）：

```bash
nx update          # 更新全部 input，写入 flake.lock；nx update nixpkgs 只更新 nixpkgs
nx diff            # 预览软件包会怎么变
nx switch          # 满意再切换
```

`nx update` 只改 `flake.lock`，不构建、不切换。不满意可以 `git checkout flake.lock` 退回上一个版本。**第一次跑 `nx update` 会生成正式的锁，之后就自动进入正式模式**，`~/nix-inputs/` 不再被使用，可以删除。

**过渡模式下的注意事项**：
- **不要删除 `~/nix-inputs/`**，否则下一次构建会失败，或回退去 GitHub 下载并可能版本不匹配。
- **直接敲 `nix flake show`、`nixos-rebuild` 等命令会联网下载**，请用 `./scripts/nixos.sh`。
- 当前系统和旧版本不依赖这些目录（源码已复制进 `/nix/store`），只是影响"再次构建"。

**没有锁文件时的退路**：如果 `nx update` 之后新版本有问题，除了 `git checkout flake.lock`，也可以在开机菜单里选上一个系统版本回滚。

## 代理（访问 GitHub 慢）

这台机器访问 GitHub 很慢，装了 mihomo（Clash 内核）作为**按需启动**的代理服务，主要给 nix 和 git 用：

```bash
nx proxy init      # 按提示粘贴订阅地址（输入不显示），脚本下载订阅并生成配置
nx proxy on        # 启动，本机代理端口 127.0.0.1:7890
nx proxy nodes     # 查看节点；nx proxy use <编号> 切换
nx proxy update    # 订阅节点变了，重新下载
nx proxy off       # 停止（不用时不占电，服务不随开机启动）
```

- 配置 = 基础设置（`examples/mihomo/config.example.yaml`）+ 订阅自带的节点、节点组和规则。生成的 `~/.config/mihomo/config.yaml` 和订阅地址文件**在仓库外，绝不要提交**。
- 透明代理（TUN）默认**关闭**（更省电），需要全局代理时 `nx proxy tun on`，用完 `nx proxy tun off`，不需要重新构建。TUN 关闭时，程序要设置 `https_proxy=http://127.0.0.1:7890` 才走代理。
- TUN 在这台机器上踩过两个坑，都已处理并实测验证（都在 `modules/nixos/mihomo.nix`）：防火墙严格的反向路径过滤会丢掉 TUN 回包，导致系统 DNS 失效（设为 `loose`）；防火墙不放行从 TUN 网卡进来的新连接，导致 `mixed` 栈 TCP 连不上（把 `Meta` 设为受信任网卡）。**第一次开启时请保留一个已登录的 SSH 会话兜底**。
- 没有安装 webui，管理都通过 `nx proxy`。详见 `scripts/README.md`。

## 软件与服务

| 类别 | 内容 |
|---|---|
| 桌面 | Niri 26.04、Noctalia 5.4（Shell）、greetd + tuigreet、alacritty、grim + slurp |
| 电源 | TLP（`power-profiles-daemon` 必须关闭，两者互斥）、UPower（电池显示） |
| 连接 | NetworkManager、BlueZ（蓝牙，开机默认不上电以省电）、OpenSSH、mihomo（代理，按需启动） |
| 字体 | CaskaydiaCove Nerd Font、Noto CJK 中文 |
| 命令行 | Nushell + Starship 提示符（登录 shell 仍是 bash，输入 `nu` 进入 Nushell） |
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
