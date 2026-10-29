# 开发环境（用户级，home-manager）：只放 imports，具体内容按职责拆在下面。
#   git.nix  版本控制相关工具（gh）
#   build.nix 构建类工具（gcc）
#   files.nix 文件搜索、查看和压缩（rg、fd、jq、tree、file、zip 系列）
#   system.nix 系统监控和剪贴板（btop、lsof、wl-clipboard）
#   network.nix 网络调试（dig）
#   lang/    语言工具链，全局安装，每种语言一个文件
{ ... }:
{
  imports = [
    ./git.nix
    ./build.nix
    ./files.nix
    ./system.nix
    ./network.nix
    ./lang
  ];
}
