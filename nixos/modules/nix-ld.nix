# nix-ld：让 NixOS 能运行"为普通 Linux 编译的预编译二进制"。
# NixOS 没有标准的 /lib64/ld-linux 动态链接器路径，这类程序默认会报 "No such file or directory"；
# 开启后系统会提供一个兼容的加载器和一组常用库。
# 目前给 rustup 下载的 Rust 工具链用；以后其他下载来的二进制（编辑器插件、语言服务器等）也能受益。
# 排查方向：运行程序报 "cannot execute" 或找不到动态库，用 `ldd` 看缺哪个库，
# 再把对应包加进 programs.nix-ld.libraries
{ ... }:
{
  programs.nix-ld.enable = true;
}
