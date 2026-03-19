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
    insurance.registerPolicy{value: 0.005 ether}("wheat", 5);

    //check policy was created 
    CropInsurance.Policy memory policy = insurance.getPolicy(farmer);
 

    assertEq(policy.farmer, farmer);
    assertEq(policy.cropType, "wheat");
    assertEq(policy.landArea, 5);
    assertEq(policy.premiumPaid, 0.005 ether);
    assertEq(policy.coverageAmount, 0.05 ether);
  }

  function test_ActivatePolicy() public {
    vm.deal(farmer, 1 ether);

    vm.prank(farmer);
    insurance.registerPolicy{value: 0.005 ether}("wheat", 5);

    insurance.activatePolicy(farmer);
    CropInsurance.Policy memory policy = insurance.getPolicy(farmer);

    assertEq(uint(policy.status), uint(CropInsurance.PolicyStatus.ACTIVE));

  }

  function test_processClaim() public {
    
    vm.deal(farmer, 1 ether);

    vm.prank(farmer);
    insurance.registerPolicy{value: 0.005 ether}("wheat", 5);

    insurance.activatePolicy(farmer);
    
    vm.deal(address(insurance), 1 ether);

    insurance.processClaim(farmer);
    CropInsurance.Policy memory policy = insurance.getPolicy(farmer);

    assertEq(uint(policy.status), uint(CropInsurance.PolicyStatus.CLAIMED));

    // check farmer got paid
    assertGt(farmer.balance, 0);
    

  }

  function test_RevertIfNoPremium() public {
    vm.deal(farmer, 1 ether);
    vm.prank(farmer);
    vm.expectRevert("incorrect premium amount");
    insurance.registerPolicy{value: 0.001 ether}("wheat", 5);
  } 

  function test_OnlyOwnerCanProcess() public{
    
    vm.deal(farmer, 1 ether);
    vm.prank(farmer);
    insurance.registerPolicy{value: 0.005 ether}("wheat", 5);
    
    address randomPerson = makeAddr("randomPerson");
    vm.prank(randomPerson);

    vm.expectRevert("not owner");
    insurance.processClaim(farmer);
  }

  function test_expirePolicy() public{
    vm.deal(farmer, 1 ether);
    vm.prank(farmer);
    insurance.registerPolicy{value: 0.005 ether}("wheat", 5);
    
    insurance.activatePolicy(farmer);
    
    uint256 balanceBefore = farmer.balance;
    
    vm.warp(block.timestamp + 181 days);

    insurance.expirePolicy(farmer);

    CropInsurance.Policy memory policy = insurance.getPolicy(farmer);

    assertEq(uint(policy.status), uint(CropInsurance.PolicyStatus.EXPIRED));
    assertGt(farmer.balance , balanceBefore);
  }

}