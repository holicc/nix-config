# 命令行环境：Nushell（现代 shell）+ Starship（命令行提示符）
#
# 刻意不把 Nushell 设为登录 shell（users.users.joe.shell）：
#   登录 shell 仍是 bash。SSH 登录和各种脚本、教程里的命令都按 bash/POSIX 语法写，
#   Nushell 不兼容这些语法，设成登录 shell 会让 `ssh 主机 'bash 命令'` 这类用法全部出错。
#   想用 Nushell 时在终端里输入 `nu` 即可；之后想让 Alacritty 默认启动 nu，再单独配置。
{ ... }:
{
  # Nushell：命令输出是结构化的表格，可以直接按列过滤、排序，如 `ls | where size > 1mb`。
  # home-manager 会生成它的 config.nu / env.nu。
  # 排查方向：Nushell 版本升级后偶有语法变化，报错先查 nushell.sh 的更新说明
  programs.nushell.enable = true;

  # Starship：提示符里显示 git 分支和状态、当前语言版本、命令耗时、上一条命令的错误码。
  # 跨 shell，这里同时在 bash 和 Nushell 里启用，所以不管用哪个都有同样的提示符。
  # 图标需要 Nerd Font（modules/nixos/fonts.nix 已安装 CaskaydiaCove Nerd Font）；
  # 终端里图标显示成方框的话，要把 Alacritty 的字体设成 CaskaydiaCove Nerd Font
  programs.starship = {
    enable = true;
    enableBashIntegration = true;
    enableNushellIntegration = true;
  };
}
