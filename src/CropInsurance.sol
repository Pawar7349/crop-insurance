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

    farmers.push(msg.sender);

    emit PolicyCreated(msg.sender, _cropType, coverage);

  }


  function activatePolicy(address _farmer) external onlyOwner {
    require(policies[_farmer].status == PolicyStatus.INACTIVE, "Policy not inactive");
    policies[_farmer].status = PolicyStatus.ACTIVE;
    totalActiveCoverage += policies[_farmer].coverageAmount;
  }

  function claimPendingRefund(address _farmer) external {
    require(policies[_farmer].status == PolicyStatus.INACTIVE , "pilicy already Active");
    require(block.timestamp > policies[_farmer].startDate + 7 days, "7 days not passed");
    uint256 payout = policies[_farmer].premiumPaid;
    payable(_farmer).transfer(payout);
    policies[_farmer].status = PolicyStatus.EXPIRED;
    emit  PolicyExpired(_farmer);
  }

  function processClaim (address _farmer) external onlyOwner hasActivePolicy(_farmer) {
    uint256 payout = policies[_farmer].coverageAmount;
    payable(_farmer).transfer(payout);
    totalActiveCoverage -= policies[_farmer].coverageAmount;
    policies[_farmer].status = PolicyStatus.CLAIMED;

    emit ClaimPaid(_farmer, payout);

  }

  function expirePolicy (address _farmer) external hasActivePolicy(_farmer) {

    require(block.timestamp > policies[_farmer].endDate, "Policy not expired yet");

    uint256 refund = policies[_farmer].premiumPaid/2;
    payable(_farmer).transfer(refund);

    totalActiveCoverage -= policies[_farmer].coverageAmount;
    policies[_farmer].status = PolicyStatus.EXPIRED;

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
    payable(owner).transfer(profit);
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

    require(policies[farmer].status == PolicyStatus.ACTIVE, "No active policy");
    require(block.timestamp > policies[farmer].endDate, "Policy not expired yet");
    
    uint256 refund = policies[farmer].premiumPaid / 2;
    payable(farmer).transfer(refund);

    totalActiveCoverage -= policies[farmer].coverageAmount;
    policies[farmer].status = PolicyStatus.EXPIRED;

    emit PolicyExpired(farmer);
    emit PremiumRefunded(farmer, refund);
  }

}




