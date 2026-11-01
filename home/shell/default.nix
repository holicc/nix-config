# 命令行环境：zsh + Starship（命令行提示符）
#
# 刻意不把 zsh 设为登录 shell（users.users.joe.shell）：
#   登录 shell 仍是 bash，SSH 登录和各种脚本按 bash/POSIX 习惯运行最稳妥。
#   桌面上的 Alacritty 直接启动 zsh（见 home/alacritty/default.nix 的 terminal.shell）；
#   SSH 登录进去还是 bash，想用 zsh 时输入 `zsh`。
{ lib, pkgs, ... }:
let
  # Nerd Font 图标是私有区字符，直接写进源文件容易在复制、编辑时丢失，
  # 所以用 JSON 的 \u 转义按码点生成（Nix 字符串本身不支持 \u 转义）
  icon = code: builtins.fromJSON ''"\u${code}"'';
in
{
  programs.zsh = {
    enable = true;
    # 补全：Tab 补出路径和命令，不区分大小写
    enableCompletion = true;
    # 输入时根据历史给出灰色建议，按右方向键接受
    autosuggestion.enable = true;
    # 命令输错时标红，正确时标绿
    syntaxHighlighting.enable = true;

    # 历史：上限 500 万条，多个终端窗口共享，重复命令只留一条
    history = {
      size = 5000000;
      save = 5000000;
      share = true;
      ignoreAllDups = true;
    };

    # oh-my-zsh 只用它的几个插件：
    #   git                      gst、gco、gcb、gcmsg、gp、gl 等 git 短命令（清单见 `alias | grep git`）
    #   sudo                     双击 Esc，在当前命令前加 sudo
    #   extract                  `x 文件` 解压任意格式的压缩包
    #   history-substring-search 输入前缀后，上下方向键只翻匹配的历史
    # 插件由 home-manager 从 nixpkgs 取，不联网克隆；不设主题，提示符仍是 Starship。
    # 这些别名只在 zsh 里有，bash 里没有
    oh-my-zsh = {
      enable = true;
      plugins = [
        "git"
        "sudo"
        "extract"
        "history-substring-search"
      ];
    };

    # 常用别名（只在 zsh 里生效；bash 保持原样）
    shellAliases = {
      ll = "ls -l";
      la = "ls -a";
    };

    initContent = lib.mkMerge [
      # fzf-tab：把 Tab 补全菜单换成 fzf 界面。必须在补全初始化之后加载（order 570 是 compinit），
      # 并且在语法高亮、自动建议之前
      (lib.mkOrder 900 "source ${pkgs.zsh-fzf-tab}/share/fzf-tab/fzf-tab.plugin.zsh")
      ''
      # 把 ~/.local/bin 加进 PATH（自己装的工具常放在这里）
      typeset -U path
      path=(~/.local/bin $path)

      # 补全菜单：Tab 后可以用方向键选择，大小写不敏感
      zstyle ':completion:*' menu select
      zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

      # nx（~/nixos-config/scripts/nixos.sh 的包装）的 Tab 补全：carapace 只认识它自带规格库里的命令，
      # nx 是自己的脚本，所以在这里声明子命令。新增或改名子命令时同步修改下面的列表
      _nx() {
        case $CURRENT in
          2) compadd check build diff test boot switch update gens pkgs gc status proxy help ;;
          3) [[ $words[2] == proxy ]] && compadd add list switch rm update on off status tun nodes use usage help ;;
          4) [[ $words[2] == proxy && $words[3] == tun ]] && compadd on off ;;
        esac
      }
      compdef _nx nx
      ''
    ];
  };

  # 下面几个小工具都自带 zsh 集成，home-manager 会把初始化代码写进 .zshrc。

  # zoxide：记住常去的目录，`z 关键字` 直接跳过去，`zi` 交互式选择。用得越多越准
  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  # fzf：`Ctrl-R` 模糊搜历史，`Ctrl-T` 搜文件，`Alt-C` 模糊跳目录；也是上面 fzf-tab 的依赖
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  # carapace：给 git、cargo、kubectl、nix 等外部命令提供子命令和参数补全
  programs.carapace = {
    enable = true;
    enableZshIntegration = true;
  };

  # direnv + nix-direnv：进入带 flake.nix 的项目目录时自动加载它的开发环境（nix develop），
  # 离开自动卸载。项目里放一个 `.envrc`（内容 `use flake`）并执行一次 `direnv allow` 即可。
  # nix-direnv 会缓存环境，进入目录是瞬间的，也不会被 nix 垃圾回收清掉
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    enableZshIntegration = true;
  };

  # Starship：提示符里显示 git 分支和状态、nix-shell 环境、命令耗时、上一条命令是否失败。
  # 跨 shell，这里同时在 bash 和 zsh 里启用，所以不管用哪个都有同样的提示符。
  # 图标需要 Nerd Font：Alacritty 已设成 CaskaydiaCove Nerd Font（见 home/alacritty/default.nix）。
  # 配色用 Catppuccin Macchiato，与 Noctalia、Alacritty 保持一致
  programs.starship = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;

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
