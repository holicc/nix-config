# nixos-config

nixos-dev 的 flake 配置（Niri + Noctalia，续航优先）。

- 应用：`git add . && sudo nixos-rebuild switch --flake .#nixos-dev`
- Rust 开发环境走项目级 `nix develop`，不在系统全局安装，模板见 `examples/rust-flake-template/flake.nix`
- `/boot` 挂载选项改动需整机重启；`system.stateVersion` 保持 `"26.05"`
- `nixos/hardware-configuration.nix` 沿用机器上已有的文件
