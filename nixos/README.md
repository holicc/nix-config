# nixos/

系统入口。`flake.nix` 里的 `nixosConfigurations.nixos-dev` 从这里开始。

| 文件 | 作用 |
|---|---|
| `configuration.nix` | 只做 imports，引入 `modules/nixos/` 下的各模块，并设置 `system.stateVersion = "26.05"` |
| `hardware-configuration.nix` | 由 `nixos-generate-config` 生成的硬件配置（分区、挂载点、内核模块），**不要手改** |

## 说明

- `hardware-configuration.nix` 来自机器上的 `/etc/nixos/hardware-configuration.nix`。里面包含磁盘分区的 UUID 等硬件信息，不含密码或密钥。重装系统或换磁盘后，要重新生成并替换这个文件。
- 只有一台机器，所以没有 `hosts/<主机名>/` 这一层；以后添加第二台机器时，再把这个目录改成 `hosts/<名字>/`。
- `/boot` 挂载选项（`fmask=0077,dmask=0077`）改动后必须整机重启才生效。
