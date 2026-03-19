//SPDX-License-Identifier: MIT
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
  

  constructor(){
    owner = msg.sender;
  }

  modifier onlyOwner(){
    require(msg.sender == owner, "not owner");
    _;
  }

  modifier hasActivePolicy(address _farmer){
    require(policies[_farmer].status == PolicyStatus.ACTIVE, "No active policy");
    _;
  }

  event PolicyCreated(address indexed farmer, string cropType, uint256 coverageAmount);
  event ClaimPaid(address indexed farmer, uint amount );
  event PolicyExpired(address indexed farmer);

  function registerPolicy(string memory _cropType, uint256 _landArea) external payable{
    require(msg.value > 0,  "send eth to buy policy");
    require(policies[msg.sender].status == PolicyStatus.INACTIVE || policies[msg.sender].farmer == address(0), "Policy already exiests");

    uint256 premium = msg.value;
    uint256 coverage = premium * 10;

    policies[msg.sender] = Policy({
      farmer:msg.sender,
      cropType: _cropType,
      landArea:_landArea,
      premiumPaid:premium,
      coverageAmount: coverage,
      startDate: block.timestamp,
      endDate:block.timestamp + 180 days,
      status: PolicyStatus.INACTIVE
    });

    emit PolicyCreated(msg.sender, _cropType, coverage);

  }

  function activatePolicy(address _farmer) external onlyOwner {
    require(policies[_farmer].status == PolicyStatus.INACTIVE, "Policy not inactive");
    policies[_farmer].status = PolicyStatus.ACTIVE;
  }

  function processClaim (address _farmer) external onlyOwner hasActivePolicy(_farmer) {
    uint256 payout = policies[_farmer].coverageAmount;
    payable(_farmer).transfer(payout);
    policies[_farmer].status = PolicyStatus.CLAIMED;

    emit ClaimPaid(_farmer, payout);

  }

  function expirePolicy (address _farmer) external hasActivePolicy(_farmer) {
    require(block.timestamp > policies[_farmer].endDate, "Policy not expired yet");
    policies[_farmer].status = PolicyStatus.EXPIRED;

    emit PolicyExpired(_farmer);
  }

  function getPolicy(address _farmer) external view returns(Policy memory){
    return policies[_farmer];
  }

  

}