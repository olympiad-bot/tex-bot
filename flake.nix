{
  description = "Provides containers to run tex-bot (Discord LaTeX rendering bot)";

  inputs = {
    docker-tools.url = "github:Danie-1/docker-tools-flake";
    tex2image.url = "git+file:///home/daniel/Documents/projects/tex2image";
  };

  outputs = { ... }: {
    nixosModules.default = { config, lib, ... }: let
      cfg  = config.services.tex-bot;
      auto = cfg.tex2image-instance == null;
      tex2imageHost = if auto then "tex2image" else cfg.tex2image-instance.host;
      tex2imagePort = if auto then 8000       else cfg.tex2image-instance.port;
    in {
      options.services.tex-bot = with lib; with types; {
        enable = mkOption {
          type = bool;
          default = false;
          description = "Whether to run the tex-bot service.";
        };
        token-file = mkOption {
          type = str;
          default = "/run/secrets/tex-bot-token";
          description = "Path to env file containing the Discord bot token (file content should be 'TOKEN=...').";
        };
        test-guild = mkOption {
          type = nullOr str;
          default = null;
          description = "Discord guild ID for syncing test commands.";
        };
        docker-network = mkOption {
          type = str;
          default = if config.services.tex-bot.tex2image-instance == null then config.services.tex2image.docker-network else "tex-bot";
          description = "Docker network to attach containers to. Default: 'tex2image' when using the auto-provisioned service, 'tex-bot' otherwise.";
        };
        tex2image-instance = mkOption {
          type = nullOr (submodule {
            options = {
              host = mkOption {
                type = str;
                description = "Hostname of the external tex2image service.";
              };
              port = mkOption {
                type = port;
                default = 8000;
                description = "Port of the external tex2image service.";
              };
            };
          });
          default = null;
          description = ''
            How to reach the tex2image LaTeX rendering service.
            null (default) — auto-enable the tex2image service and use it on docker network tex2image.
            { host, port? } — use an external instance at the given host/port.
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        docker-tools.networks = [ cfg.docker-network ];
        virtualisation.oci-containers.containers."tex-bot" = {
          serviceName = "tex-bot";
          image = "ghcr.io/olympiad-bot/tex-bot";
          environment = {
            TEX2IMAGE_HOST = tex2imageHost;
            TEX2IMAGE_PORT = toString tex2imagePort;
          } // lib.optionalAttrs (cfg.test-guild != null) {
            TEST_GUILD_ID = cfg.test-guild;
          };
          environmentFiles = [ cfg.token-file ];
          dependsOn = lib.optionals auto [ "tex2image" ];
          extraOptions = [
            "--network-alias=bot"
            "--network=${cfg.docker-network}"
          ];
        };
      };
    };
  };
}
