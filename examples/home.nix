{ pkgs, config, lib, home, specialArgs, ... }@allArgs:

{

  programs.waybar.enable = true;
  programs.waybar.settings.mainBar = {

    modules-right = [
      "custom/upower"
    ];

    "custom/upower" = {
      exec = "${pkgs.luaPackages.waybar_upower}/bin/waybar_upower run";
      format = "{icon}  {percentage}%";
      format-icons = {
        Discharging = [ "⬇" "⬇" "⬇" "⬇" "⬇" ];
        Charging = [ "⬆" "⬆" "⬆" "⬆" "⬆" ];
        "Fully charged" = [ "" "" "" "" "" ];
      };
      return-type = "json";
      restart-interval = 60;
      tooltip = true;
      hide-empty-text = true;
    };

  };

  programs.waybar.style = ''
    #custom-upower {
      color: @blue;
    }

    #custom-upower.low {
        color: @yellow;
    }

    #custom-upower.critical,
    #custom-upower.action {
      color: @red;
    }
  '';

}
