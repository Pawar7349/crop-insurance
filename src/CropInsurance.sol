// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract CropInsurance {

  enum PolicyStatus {
    INACTIVE,
    ACTIVE,
    CLAIMED,
    EXPIRED
  }

  struct Policy {
    address farmer;         
    string  cropType;       
    uint256 landArea;       
    uint256 premiumPaid;    
    uint256 coverageAmount; 
    uint256 startDate;      
    uint256 endDate;        
    PolicyStatus status;    
  }

  address public owner;
  mapping(address => Policy) public policies;

  

}