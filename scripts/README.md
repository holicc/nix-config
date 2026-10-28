# scripts/

## nixos.sh

维护脚本，封装了常用命令和**本地 input 覆盖参数**（原因见根目录 `README.md` 的"为什么要本地 input"）。

```bash
nx <命令>                    # 推荐：在任何目录都能用（home/default.nix 里装的包装命令）
./scripts/nixos.sh <命令>    # 等价，在仓库目录里直接运行
```

`nx` 只是转调 `~/nixos-config/scripts/nixos.sh`，所以修改脚本后立即生效，不需要重新 switch。
仓库如果不在 `~/nixos-config`，要同步修改 `home/default.nix` 里 `nx` 的路径。下文的命令都可以把 `./scripts/nixos.sh` 换成 `nx`。

| 命令 | 作用 | 需要 sudo |
|---|---|---|
| `check` | 求值系统配置 + 用 `niri validate` 校验生成的 KDL，不构建，改完配置先跑这个 | 否 |
| `build` | 构建但不切换，输出结果的 store 路径（不在仓库里留 `result` 链接） | 否 |
| `diff` | 构建并和当前系统对比软件包差异，**无输出表示软件包没变** | 否 |
| `test` | 校验后立即切换，但不写入开机项，重启后回到旧配置 | 是 |
| `boot` | 校验后设为下次开机使用，不立即切换 | 是 |
| `switch` | 校验后构建并立即切换，下次开机也用它 | 是 |
| `gens` | 列出所有系统版本（可回滚） | 否 |
| `pkgs` | 列出已安装的软件包和字体 | 否 |
| `gc` | 清理 7 天前的旧版本，之后无法回滚到更早的版本 | 是 |
| `status` | 内核、系统版本、本地 input 是否存在、仓库状态、关键服务 | 否 |
| `proxy init` | 提示粘贴订阅地址（输入不显示），写入 `~/.config/mihomo/config.yaml`（权限 600）；配置文件不存在时先从 `examples/mihomo/config.example.yaml` 复制，已存在则只替换订阅地址那一行 | 否 |
| `proxy on` / `proxy off` | 启动 / 停止 mihomo 服务（默认不随开机启动） | 是 |
| `proxy status` | 服务状态，以及 TUN 是否开启 | 否 |
| `proxy tun on\|off` | 运行时切换透明代理（TUN），不需要重新构建 | 否 |

## 代理（mihomo）使用流程

1. `nx proxy init`，按提示粘贴订阅地址，其余配置用模板。
2. `nx proxy on` 启动。模板里 TUN 默认开启，所以启动后就是**全局代理**，所有程序不用单独设置。
3. 用完 `nx proxy off`。想只关透明代理、保留服务，用 `nx proxy tun off`（TUN 更耗电）。

**订阅地址不要提交到 git**：配置文件在仓库外（`~/.config/mihomo/`），仓库里只有不含订阅的模板。
**第一次开启 TUN 时请保留一个已登录的 SSH 会话**，万一自动路由影响了局域网，`proxy off` 可以恢复。

## 环境变量（可选）

| 变量 | 默认值 | 作用 |
|---|---|---|
| `NIXOS_HOST` | `nixos-dev` | flake 里的 `nixosConfigurations` 名称 |
| `NIXOS_USER` | `joe` | home-manager 管理的用户 |
| `NIX_INPUTS_DIR` | `~/nix-inputs` | 本地 nixpkgs / noctalia 源码副本所在目录 |

## 行为说明

- 每个命令执行前都会 `git add -A`，因为 flake 只认 git 已 track 的文件。
- 执行前会检查 `~/nix-inputs/nixpkgs` 和 `~/nix-inputs/noctalia`（需是 git 仓库）是否存在，缺失时给出明确提示。
- `test`、`boot`、`switch` 会先跑一遍 `check`，校验失败就不会去切换系统。
- 脚本**不会代输 sudo 密码**，需要时会提示你自己输入。
