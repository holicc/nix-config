# Nix 语言工具：给 Emacs（Doom 的 nix 模块）的语言服务和格式化用，命令行也能直接用。
# Doom 里：`(nix +lsp)` 需要语言服务器，`(format +onsave)` 保存时用 nixfmt 格式化。
# 注意：nixfmt 的风格和手写的不一定一致，对旧文件第一次保存会整体重排；
# 想先统一风格：在仓库里 `nixfmt $(git ls-files '*.nix')`，单独提交。
# 排查方向：Emacs 里没有 Nix 补全，先看 `which nil`，再看 `M-x eglot` 的输出 buffer。
{ pkgs, ... }:
{
  home.packages = [
    # nil：Nix 语言服务器（补全、跳转到定义、诊断）
    pkgs.nil
    # nixfmt：Nix 官方风格的格式化工具，Doom 的 nix 模块指定用它
    pkgs.nixfmt
  ];
}
