# 青简输入法（https://github.com/qingjian-team/qingjian）：自己维护的打包，源码和数据直连官方 GitHub。
# 青简在 Linux 上由三部分组成，都由 Nix 构建，`nx switch` 一次装好：
#   1. Fcitx5 插件（C++）：显示候选、转发按键，和系统的 Fcitx5 版本一致。
#   2. 资源（词库、整句模型、释义等）：官方 release 数据包 + 仓库里的 assets，固定哈希。
#   3. server（Rust）：真正的输入引擎，独立进程，由 systemd 用户服务在登录后拉起。
#      用 nixpkgs 的 Rust 编译（实测 1.95 可以，虽然官方的 rust-toolchain.toml 写的是 1.96）；
#      依赖按 Cargo.lock 确定，不用手算 cargoHash；唯一的 git 依赖（cosmic-text）
#      用 allowBuiltinFetchGit 按锁定的提交拉取，也不用手填哈希。
#
# 源码来自 flake input `qingjian`（见 flake.nix，固定在某个官方 tag）。数据包的 tag 和 sha256
# 直接读该版本源码里的 tools/release/data.lock，所以升级时没有任何哈希要手改。
#
# 升级到新版本：
#   1. nx update qingjian        查 GitHub 上最新的发布版，把 flake.nix 里 `qingjian` input 的 tag
#                                改成它，并写进 flake.lock（要代理就带上 https_proxy）
#   2. nx switch                 插件、资源、server 全部换成新版本（编译 server 约 6 分钟，
#                                可以先 nx diff 预编译）
#   3. fcitx5 -r                 重启 Fcitx5，加载新插件
# 旧版本的源码、数据包、server 留在 /nix/store，要等 `nx gc` 才释放。
#
# 首次启用后：注销再登录；在 Fcitx5 配置里取消"仅显示当前语言"，添加"青简"。
# 排查方向：
#   - systemctl --user status qingjian-server   服务是否起来
#   - journalctl --user -u qingjian-server -b   server 的日志
#   - 官方文档说 Fcitx5 的左 Shift 热键要关掉，否则和青简的 Shift 中英切换冲突
#   - 求值报错和 data.lock 有关：官方改了这个文件的格式，看下面 lock 那段的解析
#   - 编译 server 失败：新版本可能真的需要更新的 Rust，看报错里的 rustc 版本要求；
#     新增了 git 依赖时 allowBuiltinFetchGit 会照常拉取，若在纯模式求值报错再改成 outputHashes
{ lib, pkgs, inputs, ... }:
let
  upstream = inputs.qingjian;
  short = builtins.substring 0 8 upstream.rev;

  # data.lock 是一行一个 `键 = 值`，# 开头的是注释，没有 ` = ` 的行会被跳过
  lock = lib.listToAttrs (
    lib.concatMap
      (line:
        let m = builtins.match "([^ =]+) = (.*)" line;
        in lib.optional (m != null) (lib.nameValuePair (builtins.elemAt m 0) (builtins.elemAt m 1)))
      (lib.splitString "\n" (builtins.readFile "${upstream}/tools/release/data.lock"))
  );

  data = pkgs.fetchurl {
    url = "https://github.com/qingjian-team/qingjian/releases/download/${lock.tag}/qingjian-data.tar.gz";
    sha256 = lock."qingjian-data.tar.gz";
  };

  # Fcitx5 插件：只编译 apps/linux/fcitx5，但源码里有 #include "../../surrounding.h"，
  # 头文件在 apps/linux/ 下，所以要取整个源码树，再用 sourceRoot 把构建入口指到插件目录。
  # BUILD_TESTING=OFF：部分测试要先有编译好的 Rust server，这里只要插件本体
  plugin = pkgs.stdenv.mkDerivation {
    pname = "qingjian-fcitx5";
    version = short;
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

  # server：只编译 qingjian-linux-server 这一个包（workspace 里还有 macOS、设置程序等）。
  # 新版 buildRustPackage 的 cargo 钩子从环境变量读 flags，所以放在 env 里；
  # doCheck = false：测试需要数据文件和输入法环境，这里只要二进制
  server = pkgs.rustPlatform.buildRustPackage {
    pname = "qingjian-server";
    version = short;
    src = upstream;
    cargoLock = {
      lockFile = "${upstream}/Cargo.lock";
      allowBuiltinFetchGit = true;
    };
    env.cargoBuildFlags = "-p qingjian-linux-server";
    nativeBuildInputs = [ pkgs.pkg-config ];
    buildInputs = [ pkgs.openssl ];
    doCheck = false;
  };

  # 资源根目录：server 通过 QINGJIAN_RESOURCES 找它，布局是 assets/ 加 data/。
  # assets 取仓库里的 sample、glossary、levels、emoji；data 是官方数据包原样解开
  # （顶层目录是 data/，内含 generated/ 词库和 models/ 整句模型）
  resources = pkgs.runCommand "qingjian-resources-${short}"
    { nativeBuildInputs = [ pkgs.gnutar pkgs.gzip ]; } ''
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
  # startLimit*：nixpkgs 26.x 生成 unit 时会读取这两个选项，需显式赋值（和 systemd 默认一致）
  systemd.user.services.qingjian-server = {
    description = "青简输入法 server";
    wantedBy = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    startLimitIntervalSec = 10;
    startLimitBurst = 5;
    environment.QINGJIAN_RESOURCES = "${resources}";
    serviceConfig = {
      Type = "simple";
      ExecStart = "${server}/bin/qingjian-linux-server";
      Restart = "on-failure";
      RestartSec = "2";
    };
  };
}
