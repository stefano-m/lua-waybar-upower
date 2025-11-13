{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";

    lua-upower_dbus.url = "github:stefano-m/lua-upower_dbus/master";
    lua-upower_dbus.inputs.nixpkgs.follows = "nixpkgs";

  };

  outputs = { self, nixpkgs, lua-upower_dbus }:
    let

      flakePkgs = import nixpkgs {
        system = "x86_64-linux";
        overlays = [ self.overlays.default ];
      };

      currentVersion = "0.1";

      buildPackage = pname: luaPackages: with luaPackages;
        let
          derivationData = rec {
            name = "${pname}-${version}";
            inherit pname;
            version = "${currentVersion}-${self.shortRev or "dev"}";

            src = ./.;

            propagatedBuildInputs = [ lua lgi cjson upower_dbus flakePkgs.glib ];

            nativeBuildInputs = [
              flakePkgs.makeWrapper
            ];

            buildPhase = ":";

            installPhase = with flakePkgs; ''
              mkdir -p "$out/share/lua/${lua.luaversion}"
              cp -r src/${pname}.lua $out/share/lua/${lua.luaversion}/
              chmod +x $out/share/lua/${lua.luaversion}/${pname}.lua

              mkdir -p $out/bin
              makeWrapper $out/share/lua/${lua.luaversion}/${pname}.lua $out/bin/${pname} \
                  --set-default LUA_PATH ";;" \
                  --suffix LUA_PATH ';' "$LUA_PATH" \
                  --set-default LUA_CPATH ";;" \
                  --suffix LUA_CPATH ';' "$LUA_CPATH" \
                  --set-default GI_TYPELIB_PATH : \
                  --suffix GI_TYPELIB_PATH : ${lib.getLib glib}/lib/girepository-1.0
            '';

            doCheck = false;
            checkPhase = ":";
          };

          derivationData' = derivationData // {
            passthru.tests = buildLuaPackage (derivationData // {
              # Doing this so the luackeck dependencies don't end up in the
              # clousre and included in the wrapped script.
              buildInputs = [ luacheck ];
              doCheck = true;
              checkPhase = "luacheck src";
            });
          };

        in
        buildLuaPackage derivationData';

    in
    {
      packages.x86_64-linux = rec {
        default = lua_waybar_upower;
        lua_waybar_upower = buildPackage "waybar_upower" flakePkgs.luaPackages;
        lua52_waybar_upower = buildPackage "waybar_upower" flakePkgs.lua52Packages;
        lua53_waybar_upower = buildPackage "waybar_upower" flakePkgs.lua53Packages;
        luajit_waybar_upower = buildPackage "waybar_upower" flakePkgs.luajitPackages;
      };

      overlays.default = final: prev:
        let
          thisOverlay = final: prev: with self.packages.x86_64-linux; {
            # NOTE: lua = prev.lua.override { packageOverrides = this: other: {... }}
            # Seems to be broken as it does not allow to combine different overlays.

            luaPackages = prev.luaPackages // {
              waybar_upower = lua_waybar_upower;
            };

            lua52Packages = prev.lua52Packages // {
              waybar_upower = lua52_waybar_upower;
            };

            lua53Packages = prev.lua53Packages // {
              waybar_upower = lua53_waybar_upower;
            };

            luajitPackages = prev.luajitPackages // {
              waybar_upower = luajit_waybar_upower;
            };

          };
        in
        # expose the other lua overlays together with this one.
        (nixpkgs.lib.composeManyExtensions [ thisOverlay lua-upower_dbus.overlays.default ]) final prev;


      devShells.x86_64-linux.default = flakePkgs.mkShell {
        LUA_PATH = "./src/?.lua;./src/?/init.lua";

        buildInputs = (with self.packages.x86_64-linux.lua53_waybar_upower; buildInputs ++ propagatedBuildInputs) ++ (with flakePkgs; [
          nixpkgs-fmt
          luarocks
          lua53Packages.luacheck
        ]);
      };
    };
}
