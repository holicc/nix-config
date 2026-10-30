# 版本控制相关的用户级工具和配置。git 本体仍装在 nixos/modules/base.nix（系统级）：
# `sudo nixos-rebuild` 以 root 运行，读取 flake 时需要 root 的 PATH 里有 git。
{ pkgs, ... }:
{
  home.packages = [
    # gh：GitHub 官方命令行（PR、issue、仓库、登录认证）。
    # 只装命令本体，不启用 programs.gh，那个选项默认会改写 git 的凭据配置
    pkgs.gh
  ];

  # git 短命令：home.shellAliases 对 bash 和 nushell 都生效。
  # 注意 nushell 里用 `;` 连接命令，不支持 `&&`：gaa; gcm "说明"; gp
  home.shellAliases = {
    gst = "git status -sb";
    ga = "git add";
    gaa = "git add -A";
    gcm = "git commit -m";
    gp = "git push";
    gpl = "git pull";
    gd = "git diff";
    glo = "git log --oneline -10";
  };
}
