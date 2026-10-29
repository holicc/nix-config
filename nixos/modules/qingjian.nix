# 青简输入法（https://github.com/qingjian-team/qingjian）：自己维护的打包，官方源码和数据直连 GitHub。
# 青简在 Linux 上由三部分组成：
#   1. Fcitx5 插件（C++）：显示候选、转发按键。本模块用 Nix 编译，和系统的 Fcitx5 版本一致。
#   2. 资源（词库、整句模型、释义等）：官方 release 数据包 + 仓库里的 assets，本模块用 Nix 固定哈希。
#   3. server（Rust）：真正的输入引擎，独立进程。**不在本模块里编译**，由你用 rustup 手动编译后
#      放到 ~/.local/bin/qingjian-linux-server，本模块只负责登录后用 systemd 用户服务拉起它。
#      原因：官方要求 Rust 1.96，nixpkgs 26.05 只有 1.95，Nix 沙箱里又用不了本机的 rustup。
#      所以 `nx update` 管不到 server，升级时要按下面的步骤重新编译。
#
# 升级到新版本：
#   1. 改下面的 version，用 `nix-prefetch-url --unpack <源码 tarball>` 重新算 srcHash；
#   2. 看新版 tools/release/data.lock 里的 tag 和 sha256，同步改 dataTag、dataHash；
#   3. 重新编译 server（见下）；`nx switch`；重启服务：systemctl --user restart qingjian-server
#
# 编译 server（需要 rustup 的 stable、系统有 cc，见 home/dev/）：
#   git clone --branch v<version> --depth 1 https://github.com/qingjian-team/qingjian ~/src/qingjian
#   cd ~/src/qingjian
#   nix-shell -p pkg-config openssl --run \
#     'cargo build --release --locked -p qingjian-linux-server'
#   install -D target/release/qingjian-linux-server ~/.local/bin/qingjian-linux-server
#
# 首次启用后：注销再登录；在 Fcitx5 配置里取消"仅显示当前语言"，添加"青简"。
# 排查方向：
#   - systemctl --user status qingjian-server   服务是否起来（server 没编译时服务会被跳过）
#   - journalctl --user -u qingjian-server -b   server 的日志
#   - 官方文档说 Fcitx5 的左 Shift 热键要关掉，否则和青简的 Shift 中英切换冲突
{ lib, pkgs, ... }:
let
  version = "0.3.1";
  srcHash = "sha256-O7v38SYcDq2LbqJ6eLwaZFAGf4bxfwIHKyvMyVCH+hU=";

  # 数据包版本和校验值取自该版本源码里的 tools/release/data.lock
  dataTag = "data-v8";
  dataHash = "sha256-yK74EDK4yyyp9m5ToT9TC1QMDqVXCsWph23HGDiGgRY=";

  upstream = pkgs.fetchFromGitHub {
    owner = "qingjian-team";
    repo = "qingjian";
    rev = "v${version}";
    hash = srcHash;
  };

  data = pkgs.fetchurl {
    url = "https://github.com/qingjian-team/qingjian/releases/download/${dataTag}/qingjian-data.tar.gz";
    hash = dataHash;
  };

  # Fcitx5 插件：只编译 apps/linux/fcitx5，但源码里有 #include "../../surrounding.h"，
  # 头文件在 apps/linux/ 下，所以要取整个源码树，再用 sourceRoot 把构建入口指到插件目录。
  # 官方 CMake 会把 .so 装到 lib/fcitx5，addon 和 inputmethod 配置装到 share/fcitx5，
  # 符合 nixpkgs 的 fcitx5 插件布局，放进 i18n.inputMethod.fcitx5.addons 即可。
  # BUILD_TESTING=OFF：部分测试要先有编译好的 Rust server，这里只要插件本体
  plugin = pkgs.stdenv.mkDerivation {
    pname = "qingjian-fcitx5";
    inherit version;
    src = upstream;
    sourceRoot = "source/apps/linux/fcitx5";
    nativeBuildInputs = [
      pkgs.cmake
      pkgs.pkg-config
    ];
    buildInputs = [
      pkgs.fcitx5
      pkgs.nlohmann_json
    ];
    cmakeFlags = [ "-DBUILD_TESTING=OFF" ];
  };

  # 资源根目录：server 通过 QINGJIAN_RESOURCES 找它，布局是 assets/ 加 data/。
  # assets 取仓库里的 sample、glossary、levels、emoji；data 是官方数据包原样解开
  # （顶层目录是 data/，内含 generated/ 词库和 models/ 整句模型）
  resources = pkgs.runCommand "qingjian-resources-${version}" { nativeBuildInputs = [ pkgs.gnutar pkgs.gzip ]; } ''
    mkdir -p $out/assets
    for kind in sample glossary levels emoji; do
      cp -r ${upstream}/assets/$kind $out/assets/
    done
    tar -xzf ${data} -C $out
    chmod -R u+w $out
    # 数据包里混进的 macOS 冗余文件（._ 开头）不是产品数据
    find $out -name '._*' -delete
  '';
in
{
  i18n.inputMethod.fcitx5.addons = [ plugin ];

  # 用户级服务：登录后拉起 server，崩了自动重启。
  # ConditionPathExists：server 还没编译时跳过（不报错），编译好之后下次登录或手动启动即可。
  # startLimit*：nixpkgs 26.x 生成 unit 时会读取这两个选项，需显式赋值（和 systemd 默认一致）
  systemd.user.services.qingjian-server = {
    description = "青简输入法 server";
    wantedBy = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    startLimitIntervalSec = 10;
    startLimitBurst = 5;
    unitConfig.ConditionPathExists = "%h/.local/bin/qingjian-linux-server";
    environment.QINGJIAN_RESOURCES = "${resources}";
    serviceConfig = {
      Type = "simple";
      ExecStart = "%h/.local/bin/qingjian-linux-server";
      Restart = "on-failure";
      RestartSec = "2";
    };
  };
}
