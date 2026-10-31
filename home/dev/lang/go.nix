# Go 工具链（全局安装）。
{ pkgs, ... }:
{
  home.packages = [
    # go：编译器和 go 命令（构建、测试、模块管理）
    pkgs.go

    # 下面这些是给 Emacs（Doom 的 go 模块）用的，命令行也能直接用
    # gopls：Go 语言服务器（补全、跳转、诊断）
    pkgs.gopls
    # gotools：goimports（保存时整理 import）、godoc 等
    pkgs.gotools
    # gomodifytags：增删改 struct tag
    pkgs.gomodifytags
    # gotests：给函数生成测试
    pkgs.gotests
    # gore：Go 的 REPL
    pkgs.gore
  ];
}
