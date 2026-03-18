//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {CropInsurance} from "../src/CropInsurance.sol";


contract CropInsuranceTest is Test {
  CropInsurance public insurance;
  address public farmer;

  function setUp() public {
    farmer = makeAddr("farmer");
    insurance = new CropInsurance();
  }

  function test_RegisterPolicy() public {
    //give farmer eth 
    vm.deal(farmer, 1 ether);

    // farmer calls registerPolicy
    vm.prank(farmer);
    insurance.registerPolicy{value: 0.1 ether}("wheat", 5);

    //check policy was created 
    CropInsurance.Policy memory policy = insurance.getPolicy(farmer);
 

    assertEq(policy.farmer, farmer);
    assertEq(policy.cropType, "wheat");
    assertEq(policy.landArea, 5);
    assertEq(policy.premiumPaid, 0.1 ether);
    assertEq(policy.coverageAmount, 1 ether);
  }

}