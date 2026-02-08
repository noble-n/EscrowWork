// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script, console} from "lib/forge-std/src/Script.sol";
import {EscrowWork} from "src/EscrowWork.sol";

contract DeployEscrowWork is Script {

     function run() external returns (EscrowWork) {
        vm.startBroadcast();
        EscrowWork escrowWork = new EscrowWork();
        vm.stopBroadcast();
        console.log("EscrowWork deployed at:", address(escrowWork));

        return escrowWork;
    }
}