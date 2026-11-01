# 版本控制相关的用户级工具和配置。git 本体仍装在 nixos/modules/base.nix（系统级）：
# `sudo nixos-rebuild` 以 root 运行，读取 flake 时需要 root 的 PATH 里有 git。
{ pkgs, ... }:
{
  home.packages = [
    # gh：GitHub 官方命令行（PR、issue、仓库、登录认证）。
    # 只装命令本体，不启用 programs.gh，那个选项默认会改写 git 的凭据配置
    pkgs.gh
  ];

  # git 用户身份：home-manager 写到 ~/.config/git/config。
  # 和 `gh auth setup-git` 写的 ~/.gitconfig（GitHub 凭据）并存：git 两个都读，互不冲突。
  # 邮箱会公开在提交记录里（推送到 GitHub 后）；想隐藏改用 GitHub 提供的 noreply 邮箱。
  # 注意：本仓库之前的提交作者是 joe <joe@nixos-dev>，从现在起新提交会用下面这个身份。
  programs.git = {
    enable = true;
    settings.user = {
      name = "joe";
      email = "longshan.lu@longbridge-inc.com";
    };
  };
}
