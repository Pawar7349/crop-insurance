//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AutomationCompatibleInterface.sol";


contract CropInsurance is AutomationCompatibleInterface{
  AggregatorV3Interface public priceFeed;

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
  uint256 public totalActiveCoverage;
  address[] public farmers;
  

  constructor(address _priceFeed){
    owner = msg.sender;
    priceFeed = AggregatorV3Interface(_priceFeed);
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
  event PremiumRefunded(address indexed farmer, uint256 amount);

  function registerPolicy(string memory _cropType, uint256 _landArea) external payable{
    uint256 requiredPremium = calculatePremium(_cropType, _landArea);
    require(msg.value == requiredPremium, "incorrect premium amount");
  
    require(policies[msg.sender].farmer == address(0), "Policy already exiests");

    uint256 premium = msg.value;
    uint256 coverage = premium * 10;

    if(policies[msg.sender].farmer == address(0)){
      farmers.push(msg.sender);
    }

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
    totalActiveCoverage += policies[_farmer].coverageAmount;
  }

  function claimPendingRefund() external {

    Policy storage policy = policies[msg.sender];

    uint256 payout = policy.premiumPaid;

    require(address(this).balance >= payout, "insufficient pool funds");
    require(policy.status == PolicyStatus.INACTIVE , "policy already active");
    require(block.timestamp > policy.startDate + 7 days, "7 days not passed");

    policy.status = PolicyStatus.EXPIRED;

    (bool success, ) = payable(msg.sender).call{value: payout}("");
    require(success, "transfer failed");


    emit  PolicyExpired(msg.sender);
  }

  function processClaim (address _farmer) external onlyOwner hasActivePolicy(_farmer) {
    uint256 payout = policies[_farmer].coverageAmount;
    require(address(this).balance >= payout, "insufficient pool funds");

     totalActiveCoverage -= payout;
     policies[_farmer].status = PolicyStatus.CLAIMED;
    (bool success, ) = payable(_farmer).call{value: payout}("");
    require(success, "transfer failed");

    emit ClaimPaid(_farmer, payout);

  }

  function expirePolicy (address _farmer) external hasActivePolicy(_farmer) {

    uint256 refund = policies[_farmer].premiumPaid/2;
    require(address(this).balance >= refund, "insufficient pool funds");
    require(block.timestamp > policies[_farmer].endDate, "Policy not expired yet");
    
    policies[_farmer].status = PolicyStatus.EXPIRED;
    totalActiveCoverage -= policies[_farmer].coverageAmount;
    (bool success, ) = payable(_farmer).call{value: refund}("");
    require(success, "transfer failed"); 
    

    emit PolicyExpired(_farmer);
    emit PremiumRefunded(_farmer, refund);
  }

  function getPolicy(address _farmer) external view returns(Policy memory){
    return policies[_farmer];
  }

  function calculatePremium(string memory _cropType, uint256 _landArea) public view returns (uint256) { 
    

    uint256 ethPrice = uint256(getLatestPrice())/1e8;
    uint256 premium;


    if(keccak256(abi.encodePacked(_cropType)) == keccak256(abi.encodePacked("wheat"))){
      premium = (_landArea * 2 * 1e18) /ethPrice;
    }
    else if(keccak256(abi.encodePacked(_cropType)) == keccak256(abi.encodePacked("rice"))){
      premium = (_landArea * 4 * 1e18) /ethPrice;
    }
    else if(keccak256(abi.encodePacked(_cropType)) == keccak256(abi.encodePacked("cotton"))){
      premium = (_landArea * 6 * 1e18) /ethPrice;
    }
    else{
      revert("unsupported Crop");
    }

    return premium;
  }

  function withdrawProfit() external onlyOwner{
    require(address(this).balance > totalActiveCoverage, "no excess funds");
    uint256 profit = address(this).balance - totalActiveCoverage;
    (bool success, ) = payable(owner).call{value: profit}("");
    require(success, "transfer failed");
  }

  function getLatestPrice() public view returns (int256) {
    (
      ,
      int256 price,
      ,
      ,
    ) = priceFeed.latestRoundData();
    return price;
  }

  function checkUpkeep(bytes calldata) external view override returns (bool upkeepNeeded, bytes memory){

    for(uint256 i=0; i< farmers.length; i++) {
      address farmer = farmers[i];

      if(
        policies[farmer].status == PolicyStatus.ACTIVE &&
        block.timestamp > policies[farmer].endDate
      ) {
        upkeepNeeded =  true;
        return (true, abi.encode(farmer));
      }
    }
    upkeepNeeded = false;
  }


  function performUpkeep(bytes calldata performData) external override {
    address farmer = abi.decode(performData, (address));
    uint256 refund = policies[farmer].premiumPaid / 2;
    require(address(this).balance >= refund, "insufficient pool funds");
    require(policies[farmer].status == PolicyStatus.ACTIVE, "No active policy");
    require(block.timestamp > policies[farmer].endDate, "Policy not expired yet");
    
    policies[farmer].status = PolicyStatus.EXPIRED;
    totalActiveCoverage -= policies[farmer].coverageAmount;
    (bool success, ) = payable(farmer).call{value: refund}("");
    require(success, "transfer failed");

    
    emit PolicyExpired(farmer);
    emit PremiumRefunded(farmer, refund);
  }

  function getFarmers() external view returns(address[] memory){
    return farmers;
  }

}








