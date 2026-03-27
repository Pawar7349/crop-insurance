//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {CropInsurance} from "../src/CropInsurance.sol";
import {console} from "forge-std/console.sol";


contract MockPriceFeed {
  int256 public price;

  constructor(int256 _price) {
    price = _price;
  }

  function latestRoundData() external view returns(
    uint80, int256, uint256, uint256, uint80
  ) {
    return (0, price, 0, 0, 0);
  }
}

contract CropInsuranceTest is Test {
  CropInsurance public insurance;
  address public farmer;
  receive() external payable{}

  function setUp() public {
    farmer = makeAddr("farmer");
    MockPriceFeed mockFeed = new MockPriceFeed(2000e8);
    insurance = new CropInsurance(address(mockFeed));
  }

  function test_RegisterPolicy() public {
    //give farmer eth 
    vm.deal(farmer, 1 ether);

    //farmer calls registerPolicy
    uint256 premium = insurance.calculatePremium("wheat", 5);
    vm.prank(farmer);
    insurance.registerPolicy{value: premium}("wheat", 5);

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

    uint256 premium = insurance.calculatePremium("wheat", 5);
    vm.prank(farmer);
    insurance.registerPolicy{value: premium}("wheat", 5);

    insurance.activatePolicy(farmer);
    CropInsurance.Policy memory policy = insurance.getPolicy(farmer);

    assertEq(uint(policy.status), uint(CropInsurance.PolicyStatus.ACTIVE));

  }

  function test_claimPendingRefund() public {
   
    vm.deal(farmer, 1 ether);
    uint256 premium = insurance.calculatePremium("wheat", 5);
    vm.prank(farmer);
    insurance.registerPolicy{value: premium}("wheat", 5);
    
    
    vm.warp(block.timestamp + 8 days);

    vm.deal(address(insurance), 1 ether);
    vm.prank(farmer);
    insurance.claimPendingRefund();


    CropInsurance.Policy memory policy = insurance.getPolicy(farmer);
    assertGt(farmer.balance, 0);
    assertEq(uint(policy.status), uint(CropInsurance.PolicyStatus.EXPIRED));

  }

  function test_processClaim() public {
    
    vm.deal(farmer, 1 ether);

    vm.prank(farmer);
    uint256 premium = insurance.calculatePremium("wheat", 5);
    insurance.registerPolicy{value: premium}("wheat", 5);

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
    uint256 premium = insurance.calculatePremium("wheat", 5);
    insurance.registerPolicy{value: premium}("wheat", 5);
    
    address randomPerson = makeAddr("randomPerson");
    vm.prank(randomPerson);

    vm.expectRevert("not owner");
    insurance.processClaim(farmer);
  }

  function test_expirePolicy() public {
    vm.deal(farmer, 1 ether);
    uint256 premium = insurance.calculatePremium("wheat", 5);
    vm.prank(farmer);
    insurance.registerPolicy{value: premium}("wheat", 5);
    
    insurance.activatePolicy(farmer);
    vm.deal(address(insurance), 1 ether);
    
    vm.warp(block.timestamp + 181 days);

    uint256 balanceBefore = farmer.balance;
    insurance.expirePolicy(farmer);

    CropInsurance.Policy memory policy = insurance.getPolicy(farmer);
    assertEq(uint(policy.status), uint(CropInsurance.PolicyStatus.EXPIRED));
    assertGt(farmer.balance, balanceBefore);
  }

  function test_withdrawProfit() public{
    vm.deal(farmer, 1 ether);
    vm.prank(farmer);

    uint256 premium = insurance.calculatePremium("wheat", 5);
    insurance.registerPolicy{value: premium}("wheat", 5);
    insurance.activatePolicy(farmer);
    vm.deal(address(insurance), 1 ether);

    // debug
    console.log("balance:", address(insurance).balance);
    console.log("coverage:", insurance.totalActiveCoverage());
    uint256 balanceBefore = address(this).balance;
    insurance.withdrawProfit();
    assertGt(address(this).balance, balanceBefore); 
  }

  function test_CheckUpkeep() public {
    
    vm.deal(farmer , 1 ether);
  
    uint256 premium = insurance.calculatePremium("wheat", 5);
    vm.prank(farmer);

    insurance.registerPolicy{value: premium}("wheat", 5);
    insurance.activatePolicy(farmer);
    
    vm.warp(block.timestamp + 181 days);

    (bool upkeepNeeded, ) = insurance.checkUpkeep("");
    
  }

  function test_PerformUpkeep() public {
     vm.deal(farmer , 1 ether);
  
    uint256 premium = insurance.calculatePremium("wheat", 5);
    vm.prank(farmer);

    insurance.registerPolicy{value: premium}("wheat", 5);
    insurance.activatePolicy(farmer);

    vm.warp(block.timestamp + 181 days);

  }

  function test_claimPendingRefund_TooEarly() public {
    vm.deal(farmer, 1 ether);
    uint256 premium = insurance.calculatePremium("wheat", 5);
    
    vm.prank(farmer);
    insurance.registerPolicy{value: premium}("wheat", 5);
    
    
    vm.warp(block.timestamp + 3 days);
    
    vm.prank(farmer);
    vm.expectRevert("7 days not passed");
    insurance.claimPendingRefund();
  }

  function test_claimPendingRefund_AlreadyActive() public{
    vm.deal(farmer, 1 ether);

    uint256 premium = insurance.calculatePremium("wheat", 5);
    vm.prank(farmer);
    insurance.registerPolicy{value: premium}("wheat", 5);

    insurance.activatePolicy(farmer);
    vm.warp(block.timestamp + 8 days);

    vm.prank(farmer);

    vm.expectRevert("policy already active");
    insurance.claimPendingRefund();


  }

  function test_expirePolicy_TooEarly() public {
    vm.deal(farmer, 1 ether);
    
    uint256 premium = insurance.calculatePremium("wheat", 5);
    vm.prank(farmer);
    insurance.registerPolicy{value: premium}("wheat", 5);
    insurance.activatePolicy(farmer);
    vm.warp(block.timestamp + 90 days);
    
    vm.prank(farmer);
    vm.expectRevert("Policy not expired yet");
    insurance.expirePolicy(farmer);

  }

  function test_DoubleRegistration() public {
    vm.deal(farmer, 1 ether);
    
    uint256 premium = insurance.calculatePremium("wheat", 5);
    vm.prank(farmer);
    insurance.registerPolicy{value: premium}("wheat", 5);

    vm.prank(farmer);
    vm.expectRevert("Policy already exiests");
    insurance.registerPolicy{value: premium}("wheat", 5);
  }

  



  







  

  


}

