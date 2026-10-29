# 开发环境（用户级，home-manager）：只放 imports，具体内容按职责拆在下面。
#   lang/  语言工具链，全局安装，每种语言一个文件
{ ... }:
{
  imports = [
    ./lang
  ];
}
