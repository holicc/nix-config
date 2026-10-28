# 这是一个 Rust 项目的 nix develop 开发环境模板
# 使用方法：复制这个文件到你的 Rust 项目根目录下，命名为 flake.nix，
# 然后在该项目目录下执行 `nix develop` 即可进入带有完整 Rust 工具链的 shell
#
# 退出这个 shell 后（exit 或 Ctrl+D），这些工具不会残留在系统全局环境里，
# 不同项目可以使用不同的工具链版本，互不干扰。

{
  description = "Rust 开发环境";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            rustc          # Rust 编译器
            cargo          # 构建/包管理工具
            rust-analyzer  # 编辑器语言服务（配合 VS Code / neovim 等）
            clippy         # 官方 linter
            rustfmt        # 代码格式化工具
            pkg-config     # 帮很多 crate 找到系统库
            openssl        # 常见依赖，不少网络相关 crate 需要
          ];

          shellHook = ''
            echo "Rust 开发环境已就绪：$(rustc --version)"
          '';
        };
      });
}
