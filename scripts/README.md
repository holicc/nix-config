# scripts/

## nixos.sh

维护脚本，封装了常用命令，并自动处理 input 的来源：`flake.lock` 里有 `noctalia`（已用 `nx update` 生成过正式的锁）就用锁固定的 GitHub 版本，否则用 `~/nix-inputs/` 的本地源码副本做覆盖（原因和切换方式见根目录 `README.md` 的"软件版本和 flake.lock"）。

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
| `update [input...]` | 更新 flake 的 input（nixpkgs、home-manager、noctalia）并写入 `flake.lock`；不带参数更新全部，`update nixpkgs` 只更新它。直连 GitHub 很慢，需要代理时自己设环境变量（如 `https_proxy=http://127.0.0.1:7890 nx update`），脚本不管代理。只改锁文件，不构建、不切换；之后 `diff` 预览、`switch` 应用，不满意 `git checkout flake.lock` 退回。第一次运行会从过渡模式切换到正式模式 | 否 |
| `gens` | 列出所有系统版本（可回滚） | 否 |
| `pkgs` | 列出已安装的软件包和字体 | 否 |
| `gc` | 清理 7 天前的旧版本，之后无法回滚到更早的版本 | 是 |
| `status` | 内核、系统版本、本地 input 是否存在、仓库状态、关键服务 | 否 |
| `proxy init` | 提示粘贴订阅地址（输入不显示），**下载订阅**，取其中的节点、节点组、规则，拼在基础设置 `examples/mihomo/config.example.yaml` 后面，写入 `~/.config/mihomo/config.yaml`（权限 600）；订阅地址另存到 `~/.config/mihomo/subscription.url`（权限 600） | 否 |
| `proxy update` | 用保存的订阅地址重新下载，刷新节点和规则（订阅是静态拼进配置的，节点变了要手动更新；更新后重启 mihomo 才生效）；同时重新下载 `geoip.metadb` | 否 |
| `proxy on` / `proxy off` | 启动 / 停止 mihomo 服务（默认不随开机启动） | 是 |
| `proxy status` | 服务状态，以及 TUN 是否开启 | 否 |
| `proxy tun on\|off` | 运行时切换透明代理（TUN），不需要重新构建 | 否 |
| `proxy nodes` | 列出 `PROXY` 节点组的节点，当前使用的打 ✅；订阅里混着的"官网、续费入口、剩余流量、到期时间"这类信息条目不是真节点，会被隐藏 | 否 |
| `proxy use <编号或名称>` | 切换节点：编号取自 `proxy nodes` 的列表，或写节点完整名称；只改 mihomo 运行时选择，重启后可能恢复 | 否 |
| `proxy usage` | 流量统计：机场订阅的总用量、剩余、到期时间（读订阅响应头 `subscription-userinfo`，和手机上看到的一致，不是所有机场都提供），以及 mihomo 本次启动以来转发的上下行流量（重启清零）。订阅地址只在本机读取，不会打印 | 否 |

## 代理（mihomo）使用流程

1. `nx proxy init`，按提示粘贴订阅地址。脚本会下载订阅，生成配置。
2. `nx proxy on` 启动。本机代理端口是 `127.0.0.1:7890`，程序要设置 `https_proxy=http://127.0.0.1:7890` 才走代理。
3. `nx proxy nodes` 看节点，`nx proxy use <编号>` 切换；订阅自带"自动选择"组，选它就是自动挑最快的节点。
4. 节点变了用 `nx proxy update` 刷新，然后 `nx proxy off && nx proxy on` 生效。用完 `nx proxy off`。

**为什么 `init` / `update` 还要下载 `geoip.metadb`：** 订阅规则里的 `GEOIP,CN` 需要这个地理数据库。mihomo 启动时找不到会自己下载，但这台机器上下载很慢（8.4MB 实测 51 秒），超过它的 90 秒超时就 fatal 退出，服务整个起不来（日志里是 `Can't find MMDB, start download` 加 `can't download MMDB: context deadline exceeded`）。所以脚本在用户态预先下载到 `~/.config/mihomo/geoip.metadb`（超时宽松、自动重试），服务启动前由 `modules/nixos/mihomo.nix` 里的 `ExecStartPre` 以 root 复制进它的状态目录。这一项需要 `nx switch` 之后才生效。

**配置是怎么来的：** 最终配置 = 基础设置（`examples/mihomo/config.example.yaml`，端口、DNS、TUN、API 都以它为准）+ 订阅里的 `proxies` / `proxy-groups` / `rules`。订阅里的其余设置会被丢弃，所以服务商改了端口或 DNS 不会影响本机。节点组名因服务商而异，脚本自动取规则里最后一条 `MATCH` 指向的组（你的订阅里是 `FSCloud`），也可用环境变量 `MIHOMO_GROUP` 指定。

**TUN（透明代理）默认关闭**，需要时 `nx proxy tun on`，出问题 `nx proxy tun off` 即可恢复。在这台机器上它依赖 `modules/nixos/mihomo.nix` 里的两处防火墙设置，缺一不可：`checkReversePath = "loose"`（否则系统 DNS 失效）和 `trustedInterfaces = [ "Meta" ]`（否则 TCP 连不上）。**基础设置只在 `proxy init` / `proxy update` 重新生成配置时才会更新**，已有的旧配置要重新生成后才会用上新的栈和网卡名。第一次开启时请保留一个已登录的 SSH 会话。

**订阅地址和生成的配置都不要提交到 git**：它们在仓库外（`~/.config/mihomo/`），仓库里只有不含订阅的基础设置。

**订阅服务器可能按 User-Agent 返回不同格式**：脚本默认用 `clash.meta`；如果提示"没有拿到 Clash/mihomo 配置"，试 `MIHOMO_UA=clash-verge nx proxy init`。

## 环境变量（可选）

| 变量 | 默认值 | 作用 |
|---|---|---|
| `NIXOS_HOST` | `nixos-dev` | flake 里的 `nixosConfigurations` 名称 |
| `NIXOS_USER` | `joe` | home-manager 管理的用户 |
| `NIX_INPUTS_DIR` | `~/nix-inputs` | 本地 nixpkgs / noctalia 源码副本所在目录 |

## 行为说明

- 每个命令执行前都会 `git add -A`，因为 flake 只认 git 已 track 的文件。
- 过渡模式下，执行前会检查 `~/nix-inputs/nixpkgs` 和 `~/nix-inputs/noctalia`（需是 git 仓库）是否存在，缺失时给出明确提示；正式模式下不需要它们。
- `test`、`boot`、`switch` 会先跑一遍 `check`，校验失败就不会去切换系统。
- 脚本**不会代输 sudo 密码**，需要时会提示你自己输入。
