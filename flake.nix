# 系统级 flake 入口：声明依赖（inputs）和主机配置（nixosConfigurations）
# 部署：在本目录执行 `sudo nixos-rebuild switch --flake .#nixos-dev`
# 注意：flake 只识别 git 已 track 的文件，新增文件后先 `git add .`
{
  description = "nixos-dev 的 NixOS 配置（Niri + Noctalia，续航优先）";

  inputs = {
    # 主软件源：跟随 26.05 稳定分支，保证系统稳定
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    # 不稳定分支：只给个别需要新版本的软件用（目前是 nushell，见 home/shell），
    # 其余一律用上面的稳定分支。刻意不让别的 input 跟随它，避免整套系统被带着升级。
    # 单独升级：nx update nixpkgs-unstable
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    # home-manager：管理 joe 用户级配置，分支必须与 nixpkgs 版本匹配
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Noctalia 桌面 Shell：走 flake input 而非 nixpkgs 自带包，以便跟进上游。
    # 使用 main 分支（v5）。此项目接口仍在变动；若升级后 rebuild 报错，请查阅 docs.noctalia.dev
    noctalia = {
      url = "github:noctalia-dev/noctalia";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # 青简输入法源码（官方），固定在某个发布版 tag；flake = false：只要源码，不当 flake 用。
    # 升级：`nx update qingjian` 会自动把这里的 tag 改成最新发布版，细节见 nixos/modules/qingjian.nix
    qingjian = {
      url = "github:qingjian-team/qingjian/v0.3.1";
      flake = false;
    };

    # Neomacs：用 Rust 重写的 Emacs（GPU 渲染），见 home/dev/neomacs.nix。
    # 刻意不让它跟随 nixpkgs：它自带固定的 nixpkgs 和 WebKit，跟随会让构建产物对不上、缓存失效。
    # 升级：nx update neomacs
    neomacs.url = "github:holicc/neomacs";

    # Catppuccin 统一配色：一处声明风味，Alacritty、btop、bat、fzf 等自动套用（见 home/theme）
    catppuccin = {
      url = "github:catppuccin/nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      ...
    }@inputs:
    {
      # 主机名 nixos-dev，架构 x86_64-linux
      nixosConfigurations.nixos-dev = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./nixos/configuration.nix

          # home-manager 以 NixOS 模块方式集成：
          # `nixos-rebuild switch --flake .` 即可同时应用系统和用户配置
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit inputs; };
            # 若已有同名文件导致冲突，自动备份为 .backup 而不是报错
            home-manager.backupFileExtension = "backup";
            home-manager.users.joe = import ./home;
          }
        ];
      };
    };
}
