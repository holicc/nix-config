# Python 工具链（全局安装）。
{ pkgs, ... }:
{
  home.packages = [
    # python3：解释器
    pkgs.python3

    # 下面两个是给 Emacs（Doom 的 python 模块）用的，命令行也能直接用
    # pyright：语言服务器（补全、跳转、类型检查）。Doom 文档推荐 ty，但它还很新，先用成熟的 pyright
    pkgs.pyright
    # ruff：格式化和代码检查，保存时由 Doom 的 format 模块调用
    pkgs.ruff
  ];
}
