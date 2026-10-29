# 命令行环境：Nushell（现代 shell）+ Starship（命令行提示符）
#
# 刻意不把 Nushell 设为登录 shell（users.users.joe.shell）：
#   登录 shell 仍是 bash。SSH 登录和各种脚本、教程里的命令都按 bash/POSIX 语法写，
#   Nushell 不兼容这些语法，设成登录 shell 会让 `ssh 主机 'bash 命令'` 这类用法全部出错。
#   桌面上的 Alacritty 直接启动 nu（见 home/alacritty/default.nix 的 terminal.shell）；
#   SSH 登录进去还是 bash，想用 Nushell 时输入 `nu`。
{ pkgs, ... }:
{
  # vivid：按主题生成 LS_COLORS（ls 和 Nushell 里文件名的颜色）。
  # 不装它时 Nushell 用内置默认配色，其中 README 之类的文件是黄底色块，在深色主题下几乎看不清
  home.packages = [ pkgs.vivid ];

  # Nushell：命令输出是结构化的表格，可以直接按列过滤、排序，如 `ls | where size > 1mb`。
  # home-manager 会生成它的 config.nu / env.nu。
  # 排查方向：Nushell 版本升级后偶有语法或配置项变化，启动时报错先查 nushell.sh 的更新说明
  programs.nushell = {
    enable = true;

    # 会写成 config.nu 里的 $env.config
    settings = {
      # 不显示启动欢迎语
      show_banner = false;

      # 补全：模糊匹配、不区分大小写，输入几个字母就能补出路径和命令
      completions = {
        algorithm = "fuzzy";
        case_sensitive = false;
      };

      # 历史：用 sqlite 存储，上限 500 万条。isolation = true 表示按上方向键翻历史时，
      # 看不到其他正开着的终端窗口里刚输入的命令（旧历史不受影响），不会和当前会话混在一起。
      # 借鉴自 ryan4yin/nix-config
      history = {
        file_format = "sqlite";
        max_size = 5000000;
        isolation = true;
      };

      # rm 默认放进回收站而不是永久删除，手滑删错文件还能找回；真要永久删除用 `rm -p`。
      # 借鉴自 ryan4yin/nix-config
      rm.always_trash = true;

      # 表格用圆角边框，和 Catppuccin 主题的整体风格一致
      table.mode = "rounded";

      # ls 沿用 LS_COLORS 配色
      ls.use_ls_colors = true;
    };

    # 常用别名（只在 Nushell 里生效；bash 保持原样）
    shellAliases = {
      ll = "ls -l";
      la = "ls -a";
    };

    # 借鉴自 ryan4yin/nix-config
    extraConfig = ''
      # 把 ~/.local/bin 加进 PATH（自己装的工具常放在这里）
      # 文件名配色：Catppuccin Mocha，全部是前景色，没有背景色块，补全菜单反色高亮时也看得清
      $env.LS_COLORS = (vivid generate catppuccin-mocha | str trim)

      use std/util "path add"
      path add "~/.local/bin"
      $env.PATH = ($env.PATH | uniq)

      # Nushell 在终端较窄时会把放不下的表格列省略成 "..."。
      # 下面两个包装按固定宽度渲染，size 之类的列不会被藏起来
      def lsa [] {
        ls -al | table --width 350
      }

      def dus [path: string = ""] {
        if $path == "" {
          du | table --width 350
        } else {
          du $path | table --width 350
        }
      }
    '';
  };

  # 下面几个小工具都自带 Nushell 集成，home-manager 会把初始化代码写进 config.nu。

  # zoxide：记住常去的目录，`z 关键字` 直接跳过去，`zi` 交互式选择。用得越多越准
  programs.zoxide = {
    enable = true;
    enableNushellIntegration = true;
  };

  # carapace：给 git、cargo、kubectl、nix 等外部命令提供子命令和参数补全，
  # Nushell 自带的补全只覆盖路径和内部命令
  programs.carapace = {
    enable = true;
    enableNushellIntegration = true;
  };

  # direnv + nix-direnv：进入带 flake.nix 的项目目录时自动加载它的开发环境（nix develop），
  # 离开自动卸载。Rust 项目走项目级 flake（见 examples/rust-flake-template），
  # 在项目里放一个 `.envrc`（内容 `use flake`）并执行一次 `direnv allow` 即可。
  # nix-direnv 会缓存环境，进入目录是瞬间的，也不会被 nix 垃圾回收清掉
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    enableNushellIntegration = true;
  };

  # Starship：跨 shell 的提示符，这里同时在 bash 和 Nushell 里启用。
  # 样式用官方预设 catppuccin-powerline（彩色色块分段：系统、用户、目录、git、语言环境、时间），
  # 整份预设原样放在同目录的 starship-catppuccin-powerline.toml，改样式直接编辑那个文件。
  # 换别的预设：到 https://starship.rs/presets/ 下载 toml 覆盖它，
  # 或终端里 `starship preset <名字> -o 文件` 生成。
  # 预设里的分段符号和图标是 Nerd Font 私有区字符，直接复制文件即可，不要手敲或在编辑器里重新保存成别的编码。
  # 图标需要 Nerd Font：Alacritty 已设成 CaskaydiaCove Nerd Font（见 home/alacritty/default.nix）。
  # 配色是 Catppuccin Mocha（预设里的 palette），与 Noctalia、Alacritty 一致。
  # 注意：home/theme 里已经关闭了 catppuccin 官方的 starship 端口，避免和这份预设冲突
  programs.starship = {
    enable = true;
    enableBashIntegration = true;
    enableNushellIntegration = true;
    settings = builtins.fromTOML (builtins.readFile ./starship-catppuccin-powerline.toml);
  };
}
