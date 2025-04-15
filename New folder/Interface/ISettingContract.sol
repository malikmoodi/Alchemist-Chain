// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

interface ISettingContract {
    /////// SilverChainmanager, goldChainmanager
    function setAlxToken(address _alxToken) external; // done
    function setUsdt(address _usdt) external; // done
    function setSilverChainAddress(address _silverChainAddress) external; // done
    function setAlxToUsdtRate(uint256 _alxToUsdtRate) external;
    function setBoosters(address _ouro, address _boros) external;
    function setBoosterPrice(uint256 _ouroPrice, uint256 _borosPrice) external;
    function setRoiLimit(uint256 _roiLimit) external;


    //////// Silver Chain Manager 
    function setSilverClaimTax(uint256 _silverClaimTax) external;
    function setSilverCreationFeeToken(uint256 _silverCreationFeeToken) external;
    function setSilverRewardsPerPeriod(uint256 _silverRewardsPerPeriod) external;
    function setSilverUpkeepCycle(uint256 _silverUpkeepCycle) external;
    function setGCM(address _goldChainManager) external;

    //////// Gold Chain Manager 
    function setGoldClaimTax(uint256 _goldClaimTax) external;
    function setGoldCreationFeeToken(uint256 _goldCreationFeeToken) external;
    function setGoldRewardsPerPeriod(uint256 _goldRewardsPerPeriod) external; 
    function setGoldChainAddress(address _goldChainAddress) external;
    function setGoldUpkeepCycle(uint256 _upKeepCycleGold) external;
    function setRequiredSilverChains(uint256 _requiredSilverChain) external;


    /////////////// Booster
    function setMaxSupply(uint256 _maxSupply) external;
    function setManager(address _manager) external;
    
    //////// SilverChainAlchemic, goldChainAlchemic
    function pause() external;
    function unpause() external;
    function paused() external view returns (bool);
    function setWalletLimit(uint256 _walletLimit) external;
    function setRewardPerPeriod(uint256 _reward) external;
    function setSilverChainManager(address _silverChainManager) external;
    function setGoldChainManager(address _goldChainManager) external; 

    //////// General
    function setRewardPeriod(uint256 _rewardPeriod) external;

}
