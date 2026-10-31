# Markdown 工具：给 Emacs（Doom 的 markdown 模块）预览用，命令行也能直接用。
# Doom 支持 marked、pandoc、multimarkdown 任一个，找到哪个用哪个；这里装 pandoc，
# 它还能在 markdown、HTML、docx、PDF 等格式之间互转。
# 排查方向：预览没反应，先看 `which pandoc`，再看 Emacs 里 `M-x markdown-preview` 的输出。
{ pkgs, ... }:
{
  home.packages = [
    # pandoc：markdown 编译器，Doom 的 markdown-preview 调用它渲染成 HTML
    pkgs.pandoc
  ];
}
