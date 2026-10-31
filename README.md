# nixos-config

`nixos-dev`（NixOS 26.05，Ryzen 4000 笔记本）的 flake 配置：Niri + Noctalia + greetd，续航优先。

## 目录结构

```
flake.nix  flake.lock       入口和版本锁
nixos/                      系统级（需要 root）
  configuration.nix         入口，只写 imports
  modules/                  一个功能一个文件：base、power、niri、fonts、mihomo、browser、input-method、qingjian、nix-ld
home/                       用户级（home-manager）
  default.nix               入口，只写 imports
  niri/ noctalia/ alacritty/ emacs/ theme/ shell/ dev/    一个程序或用途一个目录
    emacs/init.el           Emacs 配置，软链到 ~/.config/emacs，改了重启 Emacs 即生效（不用 switch）
    dev/git.nix             gh
    dev/build.nix           gcc（提供 cc）
    dev/files.nix           rg、fd、jq、tree、file、unzip、zip、7zz
    dev/system.nix          btop、lsof、wl-clipboard
    dev/network.nix         dig（dnsutils）
    dev/claude.nix          Claude Code（unstable）
    dev/neomacs.nix         Neomacs（Rust 重写的 Emacs，来自它自己的 flake input）
    dev/lang/               语言工具链：go（含 gopls 等）、rust（rustup）、python、node、nix（nil、nixfmt）、shell（shellcheck、shfmt）
scripts/                    维护脚本，nixos.sh 装成 nx 命令（入口只做分发，实现按职责放在 lib/ 下）
examples/mihomo/            代理基础配置模板（不含订阅）
```

每个文件开头的注释说明它的作用和踩过的坑。

## 新增配置的规则

1. **软件和配置先问再加**：新增任何软件之前先确认；没有内容的文件不预先创建。
2. **按"谁来管"选位置**：
   - 需要 root（系统服务、内核、防火墙、用户组）：`nixos/modules/<功能>.nix`，一个功能一个文件，在 `nixos/configuration.nix` 里加一行 import。
   - 用户级（程序配置、命令行工具）：`home/<程序或用途>/default.nix`，在 `home/default.nix` 里加 import。
3. **开发环境**放 `home/dev/`，已有 `lang/`；其余按用途一个文件，首次需要时再建：`git.nix`（用户配置）、`container.nix`（容器和 Kubernetes 客户端）、`build.nix`（构建和任务运行）、`default.nix`（汇总 import）。
4. **语言工具链**全局安装，放 `home/dev/lang/<语言>.nix`，一种语言一个文件（已有 Go、Rust、Python、Node、Nix、Shell）；版本跟随 nixpkgs，项目里的 `flake.nix` 可以覆盖。
5. **容器**：守护进程和用户组属系统级，放 `nixos/modules/container.nix`；命令行客户端放 `home/dev/container.nix`。
6. **git 本体留在 `nixos/modules/base.nix`**：`sudo nixos-rebuild` 以 root 运行，需要 root 的 PATH 里有 git 才能读取 flake。
7. 新增文件开头写一段职责注释；位置有变化时同步更新本 README。

## 日常使用

流程：改配置 → `nx check` → `nx diff` → `nx switch` → `git commit`。

| 命令 | 作用 |
|---|---|
| `nx check` | 只校验，不构建 |
| `nx diff` | 构建并对比软件包差异，无输出表示没变 |
| `nx switch` | 校验后切换系统（需要 sudo）；`test` 不写开机项，`boot` 只设下次开机 |
| `nx update [input]` | 更新 `flake.lock`，只改锁不构建；不满意 `git checkout flake.lock`。`nx update qingjian` 会先把 flake.nix 里的 tag 升到最新发布版 |
| `nx gens` / `nx gc` / `nx status` / `nx pkgs` | 系统版本 / 只保留最新 5 个版本并回收空间 / 状态 / 已装软件 |

`nx help` 看全部命令。直连 GitHub 很慢，`nx update` 前先开代理，并带上 `https_proxy=http://127.0.0.1:7890`。

## 代理（mihomo）

| 命令 | 作用 |
|---|---|
| `nx proxy add <名字> [文件]` | 新增配置：给文件就导入，不给就粘贴订阅地址（输入不显示） |
| `nx proxy list` / `switch <名字>` / `rm <名字>` | 查看 / 切换 / 删除配置，切换时 mihomo 在运行会自动重启 |
| `nx proxy on` / `off` | 启动 / 停止（不随开机启动） |
| `nx proxy nodes` / `use <编号>` | 查看 / 切换节点 |
| `nx proxy usage` | 订阅流量用量和到期时间 |
| `nx proxy update [名字]` | 订阅节点变了，重新下载（默认当前配置） |
| `nx proxy tun on` / `off` | 透明代理开关，默认开 |

订阅地址和生成的配置在 `~/.config/mihomo/`，**绝不要提交**。

## 窗口操作（Niri）

`Mod` 是 Super 键。窗口按"列"排成横向滚动的带子，桌面（工作区）上下排列。完整定义在 `home/niri/keybindings.kdl`。

| 操作 | 快捷键 |
|---|---|
| 切到第 N 个桌面 | `Mod+1` … `9` |
| **把当前窗口移到第 N 个桌面** | `Mod+Ctrl+1` … `9` |
| 移到上 / 下一个桌面 | `Mod+Ctrl+I` / `Mod+Ctrl+U` |
| 焦点移动 | `Mod+H/J/K/L` |
| 窗口左右 / 上下移动 | `Mod+Ctrl+H/L` / `Mod+Ctrl+K/J` |
| 并进左右的列 / 拆成单独一列 | `Mod+[` `Mod+]` / `Mod+.` |
| 最大化列 / 全屏 / 浮动 | `Mod+F` / `Mod+Shift+F` / `Mod+V` |
| 关闭窗口 | `Mod+Q` |

"移动"的单位是列：一列里叠了多个窗口会整列一起走，先 `Mod+.` 拆出来再移。

## 回滚

每次 `switch` 都生成新的系统版本：开机时在 systemd-boot 菜单选上一个，或 `sudo nixos-rebuild switch --rollback`。

## 注意

- flake 只认 git 已 track 的文件，新增文件后要 `git add`（`nx` 会自动做）。
- `system.stateVersion` 和 `home.stateVersion` 保持 `"26.05"`，不随升级改。
- `/boot` 挂载选项改动后必须重启才生效。
- Niri 26.04 的配置语法比官方 main 旧，改快捷键后先 `nx check`。
- 没有自动挂起：这台机器靠 SSH 管理，挂起会断连。
