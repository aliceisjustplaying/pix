{ lib, ... }:
let
  cronJobs = lib.filter (line: line != "") (lib.splitString "\n" (builtins.readFile ../files/cron/bsky-boost));
in {
  users.users.agent.extraGroups = [ "atd" ];

  services.atd.enable = true;

  services.cron = {
    enable = true;
    systemCronJobs = cronJobs;
  };
}
