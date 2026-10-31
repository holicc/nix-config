# Claude Code（命令行 AI 编程助手）。
# 用 unstable 的包：它更新很勤，稳定分支里的版本会落后；升级：nx update nixpkgs-unstable。
# 它是闭源软件（unfree），unstable 的包集要单独允许，系统级的 allowUnfreePredicate 管不到这里。
# 首次使用：终端运行 claude，按提示登录；需要代理时先 nx proxy on（TUN 默认开，不用再设环境变量）
{
  inputs,
  lib,
  pkgs,
  ...
}:
let
  unstable = import inputs.nixpkgs-unstable {
    system = pkgs.stdenv.hostPlatform.system;
    config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [ "claude-code" ];
  };
in
{
  home.packages = [ unstable.claude-code ];
}
