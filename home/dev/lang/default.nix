# 语言工具链：全局安装，在任何目录都能直接用；每种语言一个文件。
# 项目里如果放了自己的 flake.nix，进入该目录时会覆盖这里的全局版本，两种方式可以并存。
# 版本跟随 nixpkgs，用 `nx update` 一起升级。
{ ... }:
{
  imports = [
    ./go.nix
    ./rust.nix
    ./python.nix
    ./node.nix
  ];
}
