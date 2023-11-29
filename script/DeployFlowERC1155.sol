// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import {Script, console2} from "forge-std/Script.sol";
import {FlowERC1155, DeployerDiscoverableMetaV3ConstructionConfig} from "src/concrete/FlowERC1155.sol";
import {I9R_DEPLOYER} from "./DeployConstants.sol";

contract DeployFlowERC1155 is Script {
    function run(bytes memory meta) external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYMENT_KEY");

        console2.log("DeployFlowERC1155 meta hash:");
        console2.logBytes32(keccak256(meta));

        vm.startBroadcast(deployerPrivateKey);
        FlowERC1155 deployed = new FlowERC1155(DeployerDiscoverableMetaV3ConstructionConfig(I9R_DEPLOYER, meta));
        (deployed);
        vm.stopBroadcast();
    }
}
