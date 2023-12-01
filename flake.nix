{
  description = "Flake for development workflows.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/4204f4fa7422b0124a2995e9b292aa872d6d488b";
    rain.url = "github:rainprotocol/rain.cli/6a912680be6d967fd6114aafab793ebe8503d27b";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {self, nixpkgs, rain, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        rain-cli = "${rain.defaultPackage.${system}}/bin/rain";

      in rec {
        packages = rec {
          concrete-contracts = ["Flow" "FlowERC20" "FlowERC721" "FlowERC1155"];
          build-meta-cmd = contract: ''
            ${rain-cli} meta build \
              -i <(${rain-cli} meta solc artifact -c abi -i out/${contract}.sol/${contract}.json) -m solidity-abi-v2 -t json -e deflate -l en \
              -i src/concrete/${contract}.meta.json -m interpreter-caller-meta-v1 -t json -e deflate -l en \
          '';
          build-single-meta = contract: ''
            ${(build-meta-cmd contract)} -o meta/${contract}.rain.meta;
          '';
          build-meta = pkgs.writeShellScriptBin "build-meta" (''
          set -x;
          forge build --force;
          '' + pkgs.lib.concatStrings (map build-single-meta concrete-contracts));

          deploy-single-contract = contract: ''
            forge script script/Deploy${contract}.sol:Deploy${contract} --legacy --verify --broadcast --rpc-url "''${CI_DEPLOY_RPC_URL}" --etherscan-api-key "''${EXPLORER_VERIFICATION_KEY}" \
              --sig='run(bytes)' \
              "$( ${(build-meta-cmd contract)} -E hex )" \
              ;
          '';
          deploy-contracts = pkgs.writeShellScriptBin "deploy-contracts" (''
            set -euo pipefail;
            forge build --force;
          '' + pkgs.lib.concatStrings (map deploy-single-contract concrete-contracts));

          build-flow-basic-meta = pkgs.writeShellScriptBin "build-flow-basic-meta" (''
            set -x;
            forge build --force;

            ${rain-cli} meta build \
              -i <(${rain-cli} meta solc artifact -c abi -i out/Flow.sol/Flow.json) -m solidity-abi-v2 -t json -e deflate -l en \
              -i src/concrete/basic/Flow.meta.json -m interpreter-caller-meta-v1 -t json -e deflate -l en \
              -o meta/Flow.rain.meta;
          '');

          default = build-flow-basic-meta;
        };
      }
    );

}