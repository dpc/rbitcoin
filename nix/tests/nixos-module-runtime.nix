{
  module,
  pkgs,
}:
let
  fakePackage = pkgs.writeShellScriptBin "rbitcoin-node" ''
    set -eu
    printf '%s\n' "$@" > /var/lib/rbitcoin-test/args
    trap 'touch /var/lib/rbitcoin-test/stopped; exit 0' TERM
    touch /var/lib/rbitcoin-test/started
    while true; do
      sleep 1
    done
  '';
in
pkgs.testers.runNixOSTest {
  name = "rbitcoin-nixos-module";

  nodes.machine =
    { ... }:
    {
      imports = [ module ];

      services.rbitcoin = {
        enable = true;
        package = fakePackage;
        dataDir = "/var/lib/rbitcoin-test";
        network = "regtest";
        p2p = {
          address = "127.0.0.1";
          port = 18445;
        };
        rpc.enable = true;
        extraArgs = [
          "--max-outbound"
          "4"
        ];
      };
    };

  testScript = ''
    machine.wait_for_unit("rbitcoin.service")
    machine.wait_until_succeeds("test -e /var/lib/rbitcoin-test/started")
    machine.succeed("grep -Fx -- '--datadir' /var/lib/rbitcoin-test/args")
    machine.succeed("grep -Fx -- '/var/lib/rbitcoin-test' /var/lib/rbitcoin-test/args")
    machine.succeed("grep -Fx -- '--network' /var/lib/rbitcoin-test/args")
    machine.succeed("grep -Fx -- 'regtest' /var/lib/rbitcoin-test/args")
    machine.succeed("grep -Fx -- '127.0.0.1:18445' /var/lib/rbitcoin-test/args")
    machine.succeed("grep -Fx -- '127.0.0.1:18443' /var/lib/rbitcoin-test/args")
    machine.succeed("grep -Fx -- '--max-outbound' /var/lib/rbitcoin-test/args")
    machine.succeed("grep -Fx -- '4' /var/lib/rbitcoin-test/args")
    machine.succeed("systemctl stop rbitcoin.service")
    machine.succeed("test -e /var/lib/rbitcoin-test/stopped")
  '';
}
