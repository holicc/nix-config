# Node.js 工具链（全局安装）。
{ pkgs, ... }:
{
  home.packages = [
    # nodejs：运行时，自带 npm
    pkgs.nodejs

    # 下面三个是给 Emacs（Doom 的 javascript 模块，覆盖 JS 和 TS）用的，命令行也能直接用
    # typescript-language-server：语言服务器（补全、跳转、诊断），需要下面的 typescript
    pkgs.typescript-language-server
    # typescript：tsc 编译器，语言服务器依赖它
    pkgs.typescript
    # prettier：格式化，保存时由 Doom 的 format 模块调用
    pkgs.prettier
  ];
}
