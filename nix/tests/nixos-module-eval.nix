let
  flake = builtins.getFlake (toString ../..);
  pkgs = import flake.inputs.nixpkgs {
    system = builtins.currentSystem;
  };
  fakePackage = pkgs.runCommand "rbitcoin-test-package" { } ''
    mkdir -p "$out/bin"
    touch "$out/bin/rbitcoin-node"
  '';
  system = flake.inputs.nixpkgs.lib.nixosSystem {
    inherit (pkgs.stdenv.hostPlatform) system;
    modules = [
      (import ../modules/rbitcoin.nix {
        defaultPackage = fakePackage;
      })
      {
        services.rbitcoin = {
          enable = true;
          package = fakePackage;
          dataDir = "/srv/rbitcoin";
          coldDataDir = "/srv/rbitcoin-cold";
          network = "regtest";
          logLevel = "debug";
          scripthashIndex = true;
          silentPaymentIndex = true;
          environment.RBITCOIN_IO = "uring";
          extraArgs = [
            "--max-outbound"
            "8"
          ];
          p2p = {
            address = "127.0.0.1";
            openFirewall = true;
          };
          rpc.enable = true;
          electrum = {
            enable = true;
            openFirewall = true;
          };
          esplora = {
            enable = true;
            openFirewall = true;
          };
        };
      }
    ];
  };
  cfg = system.config;
  service = cfg.systemd.services.rbitcoin;
  execStart = service.serviceConfig.ExecStart;
in
assert cfg.services.rbitcoin.p2p.port == 18444;
assert cfg.services.rbitcoin.rpc.port == 18443;
assert cfg.networking.firewall.allowedTCPPorts == [
  18444
  50001
  3000
];
assert service.environment.RBITCOIN_IO == "uring";
assert service.serviceConfig.User == "rbitcoin";
assert service.serviceConfig.Group == "rbitcoin";
assert builtins.match ".*--datadir /srv/rbitcoin.*" execStart != null;
assert builtins.match ".*--datadir-cold /srv/rbitcoin-cold.*" execStart != null;
assert builtins.match ".*--network regtest.*" execStart != null;
assert builtins.match ".*--listen 127.0.0.1:18444.*" execStart != null;
assert builtins.match ".*--rpc-listen 127.0.0.1:18443.*" execStart != null;
assert builtins.match ".*--electrum-listen 127.0.0.1:50001.*" execStart != null;
assert builtins.match ".*--esplora-listen 127.0.0.1:3000.*" execStart != null;
assert builtins.match ".*--shindex.*" execStart != null;
assert builtins.match ".*--sptweaks.*" execStart != null;
assert builtins.match ".*--log-level debug.*" execStart != null;
assert builtins.match ".*--max-outbound 8.*" execStart != null;
true
