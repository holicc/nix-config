# 系统级 flake 入口：声明依赖（inputs）和主机配置（nixosConfigurations）
# 部署：在本目录执行 `sudo nixos-rebuild switch --flake .#nixos-dev`
# 注意：flake 只识别 git 已 track 的文件，新增文件后先 `git add .`
{
  description = "nixos-dev 的 NixOS 配置（Niri + Noctalia，续航优先）";

  inputs = {
    # 主软件源：跟随 26.05 稳定分支，保证系统稳定
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    # home-manager：管理 joe 用户级配置，分支必须与 nixpkgs 版本匹配
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Noctalia 桌面 Shell：走 flake input 而非 nixpkgs 自带包，以便跟进上游。
    # 此项目接口仍在变动；若升级后 rebuild 报错，请查阅 docs.noctalia.dev
    noctalia = {
      url = "github:noctalia-dev/noctalia/legacy-v4";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }@inputs: {
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
          home-manager.users.joe = import ./home-manager/home.nix;
        }
      ];
    };
  };
}
