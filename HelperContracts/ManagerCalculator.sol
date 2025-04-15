// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "../Interface/IERC20.sol";
import "../HelperContracts/SafeMath.sol";
import "../Interface/ITimer.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract ManagerCalculator is Initializable, OwnableUpgradeable, UUPSUpgradeable{
    using SafeMath for uint256;

    event paymentRecieved(address sender, uint256 amount);
    event fallbackCalled(address sender, uint256 amount);

    string constant NOT_AUTHORIZED = "ALQH1";
    string constant NO_TOKENS = "ALQH2";
    string constant NO_CURRENCY = "ALQH3";
    string constant SHARE_NOT_100 = "ALQH4";

    address private silverManager;
    address private GoldManager;
    address private settingContract;
    address private timerContract;    

    uint256 private ouroRewardBenefit;
    uint256 private ouroUpkeepReduction;

    uint256 private borosRewardBenefit;
    uint256 private borosUpkeepReduction;

    uint256 private ouroborosRewardBenefit;
    uint256 private ouroborosUpkeepReduction;

    
    function initialize(address _silverManager, address _GoldManager, address _settingContract, address _timerContract) initializer public {
        __Ownable_init();
        __UUPSUpgradeable_init();

        silverManager = _silverManager;
        GoldManager = _GoldManager;
        settingContract = _settingContract;
        timerContract = _timerContract;

        ouroborosRewardBenefit = 10;
        ouroborosUpkeepReduction = 5;

        ouroRewardBenefit = 5;
        ouroUpkeepReduction = 2;
        
        borosRewardBenefit = 2;
        borosUpkeepReduction = 1;
    }

    function _authorizeUpgrade(address newImplementation)internal onlyOwner override{}
   /////////// Main methods

    function getRewardsToTransfer(uint256 rewardToMint, address _user ) private view returns(uint256 _rewardToMint){
            bool ouroBoosterStatus = getOuroBoosters(_user).length > 0;
            bool borosBoosterStatus = getBorosBoosters(_user).length > 0;
            uint256 ouroDay = IBooster(ouroBooster).getUserBoosterDay(_user);
            uint256 borosDay = IBooster(borosBooster).getUserBoosterDay(_user);
            
            if((!borosBoosterStatus || ITimer(timerContract).getDay() == borosDay) && ouroBoosterStatus && ITimer(timerContract).getDay() > ouroDay){
                rewardToMint = rewardToMint.add((ouroRewardBenefit).mul(rewardToMint.div(100))); 
            }else if((!ouroBoosterStatus || ITimer(timerContract).getDay() == ouroDay)  && borosBoosterStatus && ITimer(timerContract).getDay() > borosDay){
                rewardToMint = rewardToMint.add((borosRewardBenefit).mul(rewardToMint.div(100))); 
            }else if(ouroBoosterStatus && borosBoosterStatus){
                rewardToMint = rewardToMint.add((ouroborosRewardBenefit).mul(rewardToMint.div(100))); 
            }
            return rewardToMint;
    }
    function addBoosterWise(uint256 rewardToMint, uint256 tokenId) private view returns(uint256 _rewardToMint, uint256 _rewardToTransfer){
        address _user = IChains(silverChainAddress).ownerOf(tokenId);

        bool ouroStatus = IBooster(ouroBooster).balanceOf(_user) > 0 ;
        bool borosStatus = IBooster(borosBooster).balanceOf(_user) > 0 ;

        uint256 ouroPurchaseDay = IBooster(ouroBooster).getBoosterPurchaseDay(_user);
        uint256 borosPurchaseDay = IBooster(borosBooster).getBoosterPurchaseDay(_user); 
        uint256 ouroSellDay = IBooster(ouroBooster).getBoosterSellDay(_user);
        uint256 borosSellDay = IBooster(borosBooster).getBoosterSellDay(_user);   
        uint16 beneficialDays;    
        uint16 simpleDays;    
        uint256 simpleReward;    
        uint256 beneficialReward;    

        if(!borosStatus && borosSellDay <= tokenLastUpkeepTime[tokenId]){
            if(ouroPurchaseDay <= tokenLastUpkeepTime[tokenId] && ouroStatus){
                rewardToMint = rewardToMint.add((ouroRewardBenefit).mul(rewardToMint.div(100)));                 
            }else if(ouroPurchaseDay > tokenLastUpkeepTime[tokenId] && ouroStatus){
                beneficialDays = getDay().sub(ouroPurchaseDay);
                simpleDays = ouroPurchaseDay.sub(tokenLastUpkeepTime[tokenId]);

                simpleReward = rewardToMint.mul(simpleDays);
                beneficialReward = rewardToMint.mul(beneficialDays);
                _rewardToTransfer = beneficialReward.add(simpleReward);
            }
        }
        // rewardToMint = getRewardsToTransfer(rewardToMint, _user);
    }

   ///////////// setters and Getters

    function getDay() public view returns(uint256 _day){
        return ITimer(timerContract).getDay();
    }

    function setSilverManager(address _silverManager) public{
        require(settingContract == msg.sender, NOT_AUTHORIZED);
        silverManager = _silverManager;
    }

    function getSilverManager() public view returns(address _silverManager){
        return silverManager;
    }

    function setGoldManager(address _GoldManager) external  {
        require(settingContract == msg.sender, NOT_AUTHORIZED);
        GoldManager = _GoldManager;

    }
    function getGoldManager()external view returns(address _GoldManager){
        return GoldManager;
    }

    function getSettingContract() public view returns (address _settingContract) {
        return settingContract;
    }

    function setSettingContract(address _settingContract) public onlyOwner{
        settingContract = _settingContract;
    }


   ////////////// Fin
    /**
        * @dev Returns token balance of contract.   
        @param _tokenAddress Token Address 
        @param _balance Token Balance 
    */
    function getTokenBalance(address _tokenAddress) public view returns (uint256 _balance) {
        return IERC20(_tokenAddress).balanceOf(address(this));
    }
    /**
        * @dev Returns currency balance of contract.   
        @param _balance Currency Balance 
    */
    function getCurrencyBalance() public view returns (uint256 _balance) {
        return address(this).balance;
    }

    /**
        * @dev Withdraw any token balance from this contrat and can send to any address. Only Owner can call this method.   
        @param _tokenAddress Token Address 
        @param _destionation User address
        @param _amount Amount to withdraw
    */
    function withdrawToken(address _tokenAddress, address _destionation, uint256 _amount) public onlyOwner{
        uint256 tokenBalance = IERC20(_tokenAddress).balanceOf(_tokenAddress);
        require(tokenBalance > 0, NO_TOKENS);
        IERC20(_tokenAddress).transfer(_destionation, _amount);
    }

    /**
        * @dev Withdraw currency balance from this contrat and can send to any address. Only Owner can call this method.   
        @param _destionation User addres
        @param _amount Amount to withdraw
    */
    function withdrawCurrency(address _destionation, uint256 _amount) public onlyOwner {
        require(address(this).balance > 0, NO_CURRENCY);
        payable(_destionation).transfer(_amount);
    }

    receive() external payable {
        emit paymentRecieved(msg.sender, msg.value);
    }

    fallback() external payable {
        emit fallbackCalled(msg.sender, msg.value);
    }
}
