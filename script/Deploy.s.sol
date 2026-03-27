// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {CropInsurance} from "../src/CropInsurance.sol";
import {console} from "forge-std/console.sol";

contract DeployScript is Script {
    
    address constant PRICE_FEED = 0x694AA1769357215DE4FAC081bf1f309aDC325306;
    
    function run() external returns (CropInsurance) {
        vm.startBroadcast();
        CropInsurance insurance = new CropInsurance(PRICE_FEED);
        vm.stopBroadcast();
        
        console.log("Deployed at:", address(insurance));
        return insurance;
    }
}