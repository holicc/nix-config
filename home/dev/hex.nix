# Hex（本地语音输入）：来自 holicc/hex 的 hex-plus 分支，见 flake.nix 的 hex input。
# 升级：nx update hex
{ inputs, pkgs, ... }:
{
  home.packages = [ inputs.hex.packages.${pkgs.stdenv.hostPlatform.system}.default ];
}
