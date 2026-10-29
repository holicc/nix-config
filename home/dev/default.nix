# 开发环境（用户级，home-manager）：只放 imports，具体内容按职责拆在下面的文件里。
# 现在每个文件都是空的，只有职责注释；要装什么工具，逐个确认后再加到对应文件。
#   git.nix        git 的用户配置
#   files.nix      搜索、查看、数据处理类命令行工具
#   network.nix    网络调试类工具
#   container.nix  容器和 Kubernetes 的命令行客户端
#   build.nix      构建和任务运行类工具
#   lang/          语言工具链，全局安装，每种语言一个文件
{ ... }:
{
  imports = [
    ./git.nix
    ./files.nix
    ./network.nix
    ./container.nix
    ./build.nix
    ./lang
  ];
}
