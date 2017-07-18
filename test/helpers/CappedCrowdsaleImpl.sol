pragma solidity ^0.4.11;


import '../../contracts/crowdsale/CappedCrowdsale.sol';
import '../../contracts/crowdsale/FixedRate.sol';


contract CappedCrowdsaleImpl is CappedCrowdsale, FixedRate {

  function CappedCrowdsaleImpl (
    uint256 _startBlock,
    uint256 _endBlock,
    uint256 _rate,
    address _wallet,
    uint256 _cap
  )
    Crowdsale(_startBlock, _endBlock, _wallet)
    CappedCrowdsale(_cap) 
    FixedRate(_rate)
  {
  }

}
