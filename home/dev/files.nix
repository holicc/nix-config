# 文件搜索、查看和压缩类命令行工具。
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    ripgrep # rg：按内容搜索，比 grep 快，默认忽略 .gitignore 里的文件
    fd      # 按文件名搜索，比 find 好用
    jq      # 处理 JSON
    tree    # 目录树
    file    # 识别文件类型
    unzip   # 解压 .zip
    zip     # 压缩成 .zip
    _7zz    # 7zz：解压和压缩 .7z、.rar 等格式
  ];
}
