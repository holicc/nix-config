# nixos-config

`nixos-dev`（NixOS 26.05，Ryzen 4000 笔记本）的 flake 配置：Niri + Noctalia + greetd，续航优先。

## 目录结构

```
flake.nix  flake.lock      入口和版本锁
nixos/                     系统级：configuration.nix（入口）、modules/（base、power、niri、fonts、mihomo、browser）
home/                      用户级（home-manager）：niri、noctalia、alacritty、theme、shell、dev
scripts/nixos.sh           维护脚本，装成 nx 命令
examples/mihomo/           代理基础配置模板（不含订阅）
```

每个文件开头的注释说明它的作用和踩过的坑。

## 日常使用

流程：改配置 → `nx check` → `nx diff` → `nx switch` → `git commit`。

| 命令 | 作用 |
|---|---|
| `nx check` | 只校验，不构建 |
| `nx diff` | 构建并对比软件包差异，无输出表示没变 |
| `nx switch` | 校验后切换系统（需要 sudo）；`test` 不写开机项，`boot` 只设下次开机 |
| `nx update [input]` | 更新 `flake.lock`，只改锁不构建；不满意 `git checkout flake.lock` |
| `nx gens` / `nx gc` / `nx status` / `nx pkgs` | 系统版本 / 清理旧版本 / 状态 / 已装软件 |

`nx help` 看全部命令。直连 GitHub 很慢，`nx update` 前先开代理，并带上 `https_proxy=http://127.0.0.1:7890`。

## 代理（mihomo）

| 命令 | 作用 |
|---|---|
| `nx proxy init` | 粘贴订阅地址（输入不显示），生成配置 |
| `nx proxy on` / `off` | 启动 / 停止（不随开机启动） |
| `nx proxy nodes` / `use <编号>` | 查看 / 切换节点 |
| `nx proxy usage` | 订阅流量用量和到期时间 |
| `nx proxy update` | 订阅节点变了，重新下载 |
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
