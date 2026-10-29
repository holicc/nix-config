# 命令行环境：Nushell（现代 shell）+ Starship（命令行提示符）
#
# 刻意不把 Nushell 设为登录 shell（users.users.joe.shell）：
#   登录 shell 仍是 bash。SSH 登录和各种脚本、教程里的命令都按 bash/POSIX 语法写，
#   Nushell 不兼容这些语法，设成登录 shell 会让 `ssh 主机 'bash 命令'` 这类用法全部出错。
#   桌面上的 Alacritty 直接启动 nu（见 home/alacritty/default.nix 的 terminal.shell）；
#   SSH 登录进去还是 bash，想用 Nushell 时输入 `nu`。
{ ... }:
let
  # Nerd Font 图标是私有区字符，直接写进源文件容易在复制、编辑时丢失，
  # 所以用 JSON 的 \u 转义按码点生成（Nix 字符串本身不支持 \u 转义）
  icon = code: builtins.fromJSON ''"\u${code}"'';
in
{
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
      # 文件名配色：静态的 LS_COLORS，只有前景色、没有背景色块，颜色引用终端的 ANSI 调色板，
      # 所以自动跟随 Alacritty 的 Catppuccin 配色。不设它时 Nushell 用内置默认配色，
      # 其中 README 之类的文件是黄底色块，在深色主题下看不清。
      # 只写了常见类型：di 目录、ln 链接、ex 可执行、so/pi/bd/cd 特殊文件，其余文件用默认前景色
      $env.LS_COLORS = "di=1;34:ln=36:ex=32:so=35:pi=33:bd=33:cd=33:or=31:mi=31"

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

      # nx（~/nixos-config/scripts/nixos.sh 的包装）的 Tab 补全：carapace 只认识它自带规格库里的命令，
      # nx 是自己的脚本，所以在这里声明子命令。新增或改名子命令时同步修改下面的列表
      def "nu-complete nx" [] {
        [check build diff test boot switch update gens pkgs gc status proxy help]
      }
      def "nu-complete nx proxy" [] {
        [init update on off status tun nodes use usage help]
      }
      def "nu-complete nx proxy tun" [] {
        [on off]
      }
      extern "nx" [
        command?: string@"nu-complete nx"
        ...rest: string
      ]
      extern "nx proxy" [
        sub?: string@"nu-complete nx proxy"
        ...rest: string
      ]
      extern "nx proxy tun" [
        state?: string@"nu-complete nx proxy tun"
      ]
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
  # 离开自动卸载。项目里可以放自己的 flake.nix 来固定该项目的工具版本，
  # 在项目里放一个 `.envrc`（内容 `use flake`）并执行一次 `direnv allow` 即可。
  # nix-direnv 会缓存环境，进入目录是瞬间的，也不会被 nix 垃圾回收清掉
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    enableNushellIntegration = true;
  };

  # Starship：提示符里显示 git 分支和状态、nix-shell 环境、命令耗时、上一条命令是否失败。
  # 跨 shell，这里同时在 bash 和 Nushell 里启用，所以不管用哪个都有同样的提示符。
  # 图标需要 Nerd Font：Alacritty 已设成 CaskaydiaCove Nerd Font（见 home/alacritty/default.nix）。
  # 配色用 Catppuccin Macchiato，与 Noctalia、Alacritty 保持一致
  programs.starship = {
    enable = true;
    enableBashIntegration = true;
    enableNushellIntegration = true;

    settings = {
      add_newline = true;
      command_timeout = 500;
      palette = "catppuccin_macchiato";

      # 两行提示符：第一行是位置和状态，第二行只有输入符，命令再长也不会挤掉路径。
      # username / hostname 默认只在 SSH 登录时显示
      format = "$username$hostname$directory$git_branch$git_status$nix_shell$cmd_duration$line_break$character";

      character = {
        success_symbol = "[❯](bold green)";
        error_symbol = "[❯](bold red)";
      };

      directory = {
        style = "bold lavender";
        truncation_length = 3;
        truncation_symbol = "…/";
      };

      git_branch = {
        symbol = "${icon "e0a0"} "; # powerline 分支图标
        style = "bold mauve";
      };

      git_status = {
        style = "bold peach";
      };

      # 在 nix-shell / nix develop 里时提示，避免忘了自己在临时环境中（Rust 开发模板就是这样用的）
      nix_shell = {
        symbol = "${icon "f313"} "; # Nix 雪花图标
        style = "bold blue";
        format = "via [$symbol$state]($style) ";
      };

      # 命令耗时超过 2 秒才显示
      cmd_duration = {
        min_time = 2000;
        style = "bold yellow";
        format = "took [$duration]($style) ";
      };

      username = {
        style_user = "bold peach";
        format = "[$user]($style) in ";
      };

      hostname = {
        style = "bold green";
        format = "[$hostname]($style) ";
      };

      # Catppuccin Macchiato 调色板，上面的 style 里用名字引用
      palettes.catppuccin_macchiato = {
        rosewater = "#f4dbd6";
        flamingo = "#f0c6c6";
        pink = "#f5bde6";
        mauve = "#c6a0f6";
        red = "#ed8796";
        maroon = "#ee99a0";
        peach = "#f5a97f";
        yellow = "#eed49f";
        green = "#a6da95";
        teal = "#8bd5ca";
        sky = "#91d7e3";
        sapphire = "#7dc4e4";
        blue = "#8aadf4";
        lavender = "#b7bdf8";
        text = "#cad3f5";
        subtext1 = "#b8c0e0";
        subtext0 = "#a5adcb";
        overlay2 = "#939ab7";
        overlay1 = "#8087a2";
        overlay0 = "#6e738d";
        surface2 = "#5b6078";
        surface1 = "#494d64";
        surface0 = "#363a4f";
        base = "#24273a";
        mantle = "#1e2030";
        crust = "#181926";
      };
    };
  };
}
