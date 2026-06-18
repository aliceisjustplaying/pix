{ lib, pkgs, ... }:

let
  dataDir = "/var/lib/clickhouse-smoke";
  logDir = "/var/log/clickhouse-smoke";
  runtimeDir = "/run/clickhouse-smoke";
in
{
  systemd.services.clickhouse-smoke = {
    description = "ClickHouse smoke-test instance";
    wantedBy = [ "multi-user.target" ];
    after = [
      "network.target"
      "clickhouse.service"
    ];

    serviceConfig = {
      Type = "notify";
      User = "clickhouse";
      Group = "clickhouse";
      StateDirectory = "clickhouse-smoke";
      StateDirectoryMode = "0750";
      LogsDirectory = "clickhouse-smoke";
      LogsDirectoryMode = "0750";
      RuntimeDirectory = "clickhouse-smoke";
      RuntimeDirectoryMode = "0750";
      AmbientCapabilities = "CAP_SYS_NICE";
      Environment = "CLICKHOUSE_WATCHDOG_ENABLE=0";
      TimeoutStartSec = "infinity";
      ExecStart = lib.concatStringsSep " " [
        "${pkgs.clickhouse}/bin/clickhouse-server"
        "--config-file=/etc/clickhouse-server/config.xml"
        "-L ${logDir}/clickhouse-server.log"
        "-E ${logDir}/clickhouse-server.err.log"
        "-P ${runtimeDir}/clickhouse-server.pid"
        "--"
        "--display_name=smoke"
        "--listen_host=127.0.0.1"
        "--path=${dataDir}/"
        "--tmp_path=${dataDir}/tmp/"
        "--user_files_path=${dataDir}/user_files/"
        "--format_schema_path=${dataDir}/format_schemas/"
        "--user_directories.local_directory.path=${dataDir}/access/"
        "--http_port=18123"
        "--tcp_port=19000"
        "--mysql_port=19004"
        "--postgresql_port=19005"
        "--interserver_http_port=19009"
        "--prometheus.port=19363"
      ];
    };
  };
}
