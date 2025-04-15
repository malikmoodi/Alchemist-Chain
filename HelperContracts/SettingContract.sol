// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "../Interface/ISettingContract.sol";

contract SettingContract is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    address private alxToken;
    address private usdtToken;
    address private silverChain;
    address private goldChain;
    address private silverChainManager;
    address private goldChainManager;
    address private ouroBooster;
    address private borosBooster;

    uint256 private ouroPrice;
    uint256 private borosPrice;
    uint256 private alxToUsdtRate;
    uint256 private roiLimit;

    //////////////// ASC
    uint256 private ascWalletLimit; 
    uint256 private ascRewardPeriod; 
    uint256 private ascRewardPerPeriod; 

    //////////////// AGC
    uint256 private agcWalletLimit; 
    uint256 private agcRewardPeriod; 
    uint256 private agcRewardPerPeriod; 

    //////////////// Booster
    uint256 private ouroBoosterMaxSupply; 
    uint256 private borosBoosterMaxSupply; 

    /////////////// Silver Chain Manager
    uint256 private scmRewardsPerPeriod;
    uint256 private scmClaimTax;
    uint256 private scmCreationFeeToken;
    uint256 private scmRewardPeriod;
    uint256 private scmUpkeepCycle;

    /////////////// Gold Chain Manager
    uint256 private gcmRewardsPerPeriod;
    uint256 private gcmClaimTax;
    uint256 private gcmCreationFeeToken;
    uint256 private gcmRewardPeriod; 
    uint256 private gcmUpkeepCycle;
    uint256 private requiredSilverChains;

    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();        
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyOwner
    {}

    function inputAllAddresses(address _alxToken, address _usdtToken, address _silverChain, address _goldChain, 
                                address _silverChainManager, address _goldChainManager, address _ouroBooster, address _borosBooster) public onlyOwner{
        alxToken = _alxToken;
        usdtToken = _usdtToken;
        silverChain = _silverChain;
        goldChain = _goldChain;
        silverChainManager = _silverChainManager;
        goldChainManager = _goldChainManager;
        ouroBooster = _ouroBooster;
        borosBooster = _borosBooster;
    }

    //////////////////////////// Silver chain Alchemic

    function ASCPause() public onlyOwner{
        ISettingContract(silverChain).pause();
    }

    function ASCPauseStatus() public view returns(bool status){
        return ISettingContract(silverChain).paused();
    }

    function ASCUnPause() public onlyOwner{
        ISettingContract(silverChain).unpause();
    }

    function setAscWalletLimit(uint256 _ascWalletLimit) public onlyOwner{
        ascWalletLimit = _ascWalletLimit;
        ISettingContract(silverChain).setWalletLimit(ascWalletLimit);
    }

    function getAcsWalletLimit() public view returns(uint256 _ascWalletLimit){
        return ascWalletLimit;
    } 

    function setAscRewardPeriod(uint256 _ascRewardPeriod) public onlyOwner{
        ascRewardPeriod = _ascRewardPeriod;
        ISettingContract(silverChain).setRewardPeriod(ascRewardPeriod);
    }

    function getAscRewardPeriod() public view returns(uint256 _ascRewardPeriod){
        return ascRewardPeriod;
    }
    
    function setAscRewardPerPeriod(uint256 _ascRewardPerPeriod) public onlyOwner{
        ascRewardPerPeriod = _ascRewardPerPeriod;
        ISettingContract(silverChain).setRewardPerPeriod(ascRewardPerPeriod);
    }

    function getAscRewardPerPeriod() public view returns(uint256 _ascRewardPerPeriod){
        return ascRewardPerPeriod;   
    }

    ////////////////////////// Gold chain alchemic

    function AGCPause() public onlyOwner{
        ISettingContract(goldChain).pause();
    }

    function AGCPauseStatus() public view returns(bool status){
        return ISettingContract(goldChain).paused();
    }

    function AGCUnPause() public onlyOwner{
        ISettingContract(goldChain).unpause();
    }

    function setAgcWalletLimit(uint256 _agcWalletLimit) public onlyOwner{
        agcWalletLimit = _agcWalletLimit;
        ISettingContract(goldChain).setWalletLimit(agcWalletLimit);
    }

    function getAgcWalletLimit() public view returns(uint256 _agcWalletLimit){
        return agcWalletLimit;
    } 

    function setAgcRewardPeriod(uint256 _agcRewardPeriod) public onlyOwner{
        agcRewardPeriod = _agcRewardPeriod;
        ISettingContract(goldChain).setRewardPeriod(agcRewardPeriod);
    }

    function getAgcRewardPeriod() public view returns(uint256 _agcRewardPeriod){
        return agcRewardPeriod;
    }
    
    function setAgcRewardPerPeriod(uint256 _agcRewardPerPeriod) public onlyOwner{
        agcRewardPerPeriod = _agcRewardPerPeriod;
        ISettingContract(goldChain).setRewardPerPeriod(agcRewardPerPeriod);
    }

    function getAgcRewardPerPeriod() public view returns(uint256 _agcRewardPerPeriod){
        return agcRewardPerPeriod;   
    }

    ////////////////////// Booster
    function ouroBoosterPause() public onlyOwner{
        ISettingContract(ouroBooster).pause();
    }

    function ouroBoosterPauseStatus() public view returns(bool status){
        return ISettingContract(ouroBooster).paused();
    }

    function ouroBoosterUnPause() public onlyOwner{
        ISettingContract(ouroBooster).unpause();
    }

    function borosBoosterPause() public onlyOwner{
        ISettingContract(borosBooster).pause();
    }

    function borosBoosterPauseStatus() public view returns(bool status){
        return ISettingContract(borosBooster).paused();
    }

    function borosBoosterUnPause() public onlyOwner{
        ISettingContract(borosBooster).unpause();
    } 

    function setOuroBoosterMaxSupply(uint256 _ouroBoosterMaxSupply) public onlyOwner{
        ouroBoosterMaxSupply = _ouroBoosterMaxSupply;
        ISettingContract(ouroBooster).setMaxSupply(ouroBoosterMaxSupply);
    }

    function getOuroBoosterMaxSupply() public view returns(uint256 _boosterMaxSupply){
        return ouroBoosterMaxSupply;
    }

    function setBorosBoosterMaxSupply(uint256 _borosBoosterMaxSupply) public onlyOwner{
        borosBoosterMaxSupply = _borosBoosterMaxSupply;
        ISettingContract(borosBooster).setMaxSupply(borosBoosterMaxSupply);
    }

    function getBorosBoosterMaxSupply() public view returns(uint256 _boosterMaxSupply){
        return borosBoosterMaxSupply;
    }
    ///////////////////// Silver Chain Manager

    function setSilverRewardPerPeriod(uint256 _scmRewardsPerPeriod) public onlyOwner{
        scmRewardsPerPeriod = _scmRewardsPerPeriod;
        ISettingContract(silverChainManager).setSilverRewardsPerPeriod(scmRewardsPerPeriod);
    }

    function getSilverRewardPerPeriod() public view returns(uint256 _scmRewardsPerPeriod){
        return scmRewardsPerPeriod; 
    }
    
    function setScmClaimTax(uint256 _claimTax) public onlyOwner{
        scmClaimTax = _claimTax;
        ISettingContract(silverChainManager).setSilverClaimTax(scmClaimTax);
    }
    
    function getScmClaimTax() public view returns(uint256 _claimTax){
        return scmClaimTax;
    }

    function setScmCreationFeeToken(uint256 _scmCreationFeeToken) public onlyOwner{
        scmCreationFeeToken = _scmCreationFeeToken;
        ISettingContract(silverChainManager).setSilverCreationFeeToken(_scmCreationFeeToken);
    }

    function getScmCreationFeeToken() public view returns(uint256 _scmCreationFeeToken){
        return scmCreationFeeToken;
    }

    function setScmRewardPeriod(uint256 _scmRewardPeriod) public onlyOwner{
        scmRewardPeriod = _scmRewardPeriod;
        ISettingContract(silverChainManager).setRewardPeriod(scmRewardPeriod);
    }

    function getScmRewardPeriod() public view returns(uint256 _scmRewardPeriod){
        return scmRewardPeriod;
    }

    function setScmUpkeepCycle(uint256 _scmUpkeepCycle) public onlyOwner{
        scmUpkeepCycle = _scmUpkeepCycle;
        ISettingContract(silverChainManager).setGoldUpkeepCycle(scmUpkeepCycle);
    }

    function getScmUpkeepCycle() public view returns(uint256 _scmUpkeepCycle){
        return scmUpkeepCycle;
    }
    ///////////////////// Gold Chain Manager
    
    /**
    * @dev Returns gold upkeep cycle.
    @param _requiredSilverChain Upkeep cycle in days
    */  
    function getRequiredSilverChains() public view returns(uint256 _requiredSilverChain) {
        return requiredSilverChains;
    }

    /**
    * @dev Sets gold upkeep cycle. Only owner can set this value   
    @param _requiredSilverChain Upkeep cycle in days
    */ 
    function setRequiredSilverChains(uint256 _requiredSilverChain) public onlyOwner{
        requiredSilverChains = _requiredSilverChain;
        ISettingContract(goldChainManager).setRequiredSilverChains(requiredSilverChains);
    }

    function setGoldRewardPerPeriod(uint256 _gcmRewardsPerPeriod) public onlyOwner{
        gcmRewardsPerPeriod = _gcmRewardsPerPeriod;
        ISettingContract(goldChainManager).setGoldRewardsPerPeriod(gcmRewardsPerPeriod);
    }

    function getGoldRewardPerPeriod() public view returns(uint256 _gcmRewardsPerPeriod){
        return gcmRewardsPerPeriod; 
    }
    
    function setGcmClaimTax(uint256 _claimTax) public onlyOwner{
        gcmClaimTax = _claimTax;
        ISettingContract(goldChainManager).setGoldClaimTax(gcmClaimTax);
    }
    
    function getGcmClaimTax() public view returns(uint256 _claimTax){
        return gcmClaimTax;
    }

    function setGcmRewardPeriod(uint256 _gcmRewardPeriod) public onlyOwner{
        gcmRewardPeriod = _gcmRewardPeriod;
        ISettingContract(goldChainManager).setRewardPeriod(gcmRewardPeriod);
    }

    function getGcmRewardPeriod() public view returns(uint256 _gcmRewardPeriod){
        return gcmRewardPeriod;
    }

    function setGcmCreationFeeToken(uint256 _gcmCreationFeeToken) public onlyOwner{
        gcmCreationFeeToken = _gcmCreationFeeToken;
        ISettingContract(goldChainManager).setGoldCreationFeeToken(_gcmCreationFeeToken);
    }

    function getGcmCreationFeeToken() public view returns(uint256 _gcmCreationFeeToken){
        return gcmCreationFeeToken;
    }

    function setGcmUpkeepCycle(uint256 _gcmUpkeepCycle) public onlyOwner{
        gcmUpkeepCycle = _gcmUpkeepCycle;
        ISettingContract(goldChainManager).setGoldUpkeepCycle(gcmUpkeepCycle);
    }

    function getGcmUpkeepCycle() public view returns(uint256 _gcmUpkeepCycle){
        return gcmUpkeepCycle;
    }
    /////////////////// General
    
    function setAlxToUsdtRate(uint256 _rate) public onlyOwner{
        alxToUsdtRate = _rate;
        ISettingContract(silverChainManager).setAlxToUsdtRate(alxToUsdtRate);
        ISettingContract(goldChainManager).setAlxToUsdtRate(alxToUsdtRate);
    }
    
    function getAlxToUsdtRate() public view returns(uint256 _rate){
        return alxToUsdtRate;
    }

    function setAlxToken(address _alxToken) public onlyOwner {
        alxToken = _alxToken;
        ISettingContract(silverChainManager).setAlxToken(alxToken);
        ISettingContract(goldChainManager).setAlxToken(alxToken);
    }

    function getAlxToken() public view returns (address _alxToken) {
        return alxToken;
    }

    function setUsdtToken(address _usdtToken) public onlyOwner {
        usdtToken = _usdtToken;
        ISettingContract(silverChainManager).setUsdt(usdtToken);
        ISettingContract(goldChainManager).setUsdt(usdtToken);
    }

    function getUsdtToken() public view returns (address _usdtToken) {
        return usdtToken;
    }

    function setSilverChain(address _silverChain) public onlyOwner {
        silverChain = _silverChain;
        ISettingContract(silverChainManager).setSilverChainAddress(silverChain);
        ISettingContract(goldChainManager).setSilverChainAddress(silverChain);
    }

    function getSilverChain() public view returns (address _silverChain) {
        return silverChain;
    }

    function setGoldChain(address _goldChain) public onlyOwner {
        goldChain = _goldChain;
        ISettingContract(goldChainManager).setGoldChainAddress(goldChain);
    }

    function getGoldChain() public view returns (address _goldChain) {
        return goldChain;
    }

    function setSilverChainManager(address _silverChainManager) public onlyOwner {
        silverChainManager = _silverChainManager;
        ISettingContract(silverChain).setSilverChainManager(silverChainManager);
        ISettingContract(goldChain).setSilverChainManager(silverChainManager);
        ISettingContract(ouroBooster).setSilverChainManager(silverChainManager);
        ISettingContract(borosBooster).setSilverChainManager(silverChainManager);
        ISettingContract(alxToken).setSilverChainManager(silverChainManager);
    }

    function getSilverChainManager() public view returns (address _silverChainManager) {
        return silverChainManager;
    }

    // GoldChainManager
    function setGoldChainManager(address _goldChainManager) public onlyOwner {
        goldChainManager = _goldChainManager;
        ISettingContract(silverChain).setGoldChainManager(goldChainManager);
        ISettingContract(goldChain).setGoldChainManager(goldChainManager);
        ISettingContract(ouroBooster).setGoldChainManager(goldChainManager);
        ISettingContract(borosBooster).setGoldChainManager(goldChainManager);
        ISettingContract(alxToken).setGoldChainManager(goldChainManager);
        ISettingContract(silverChainManager).setGCM(goldChainManager);
    }

    function getGoldChainManager() public view returns (address _goldChainManager){
        return goldChainManager;
    }

    function setBoosterAddress(address _ouro, address _boros) public onlyOwner {
        ouroBooster = _ouro;
        borosBooster = _boros;
        ISettingContract(silverChainManager).setBoosters(_ouro, _boros);
        ISettingContract(goldChainManager ).setBoosters(_ouro, _boros);
    }

    function getBoosterAddress() public view returns (address _ouro, address _boros){
        return (ouroBooster, borosBooster);
    }


    function setBoosterPrice(uint256 _ouroPrice, uint256 _borosPrice) public onlyOwner{
        ouroPrice = _ouroPrice;
        borosPrice = _borosPrice;
        ISettingContract(silverChainManager).setBoosterPrice(_ouroPrice, _borosPrice);
        ISettingContract(goldChainManager).setBoosterPrice(_ouroPrice, _borosPrice);
    }

    function getBoosterPrice() public view returns(uint256 _ouroPrice, uint256 _borosPrice){
        return (ouroPrice, borosPrice);
    }

        /**
    * @dev Returns ROI Limit for chains.
    @param _roiLimit ROI Limit 
    */  
    function getRoiLimit() public view returns(uint256 _roiLimit) {
        return roiLimit;
    }

    /**
    * @dev Sets ROI Limit for chains. Only setting contract can set this value   
    @param _roiLimit reward per period 
    */ 
    function setRoiLimit(uint256 _roiLimit) public onlyOwner{
        roiLimit = _roiLimit;
        ISettingContract(silverChainManager).setRoiLimit(roiLimit);
        ISettingContract(goldChainManager).setRoiLimit(roiLimit);
    }
}
