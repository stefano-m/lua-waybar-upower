{
  description = "Example flake that consumes the waybar_upower module";

  inputs = {
    waybar-upower-module.url = "github:stefano-m/lua-waybar-upower/main";
    waybar-upower-module.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, home-manager, home-common, waybar-upower-module }@inputs:
    let
      system = "x86_64-linux";
      username = "theUser";
      flakePkgs = import nixpkgs {
        inherit system;
        overlays = [ waybar-upower-module.overlays.default ];
      };
    in
    {
      homeConfigurations = {
        ${username} = home-manager.lib.homeManagerConfiguration {
          modules = [
            ./home.nix
            {
              home = {
                inherit username;
                homeDirectory = "/home/${username}";
              };
            }
          ] ++ builtins.attrValues home-common.nixosModules;
          extraSpecialArgs = {
            flakeInputs = inputs;
          };
          pkgs = flakePkgs;
        };
      };
    };
}
