// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "../Interface/IERC721.sol";
import "../Interface/ITimer.sol";
import "../HelperContracts/SafeMath.sol";
import "../Interface/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

contract Ouro is Initializable, ERC721Upgradeable, PausableUpgradeable, OwnableUpgradeable, UUPSUpgradeable  {
    using CountersUpgradeable for CountersUpgradeable.Counter;
    
    event paymentRecieved(address sender, uint256 amount);
    event fallbackCalled(address sender, uint256 amount);

    CountersUpgradeable.Counter private _tokenIdCounter;

    address private silverChainManager;
    address private goldChainManager;
    address private settingContract;
    address private timerContract;
    address private usdt;

    uint256 private ouroborosPrice; 
    uint256 private _maxSupply; 
    uint256 private lastBooster;
    uint256 private totalSupply;
    uint256 private ouroPrice;



    mapping (address => uint256[]) private boosts; 
    mapping (address => uint256) private lastDay; 
    mapping (address => uint256) private purchaseDay; 
    mapping (address => uint256) private sellDay; 

    string constant NOT_AUTHORIZED = "OUR1";
    string constant MAX_SUPPLY_RECACHED = "OUR2";
    string constant NOT_TOKEN_OWNER = "OUR3";
    string constant PAUSED = "OUR4";
    string constant NO_TOKENS = "OUR5";
    string constant NO_CURRENCY = "OUR6";
    string constant NOT_NFT_OWNER = "OUR7";

    constructor() {
          _disableInitializers();
    }
    
    /**
        * @dev Initialize: Deploy Alchemic Gold Chain Manager and set the basic values 
        *
    */
    function initialize(address _settingContract, address _usdt, address _timer) initializer public {
        __ERC721_init("Ouro", "OURO");
        __Pausable_init();
        __Ownable_init();
        __UUPSUpgradeable_init();
        _maxSupply = 300;
        totalSupply = 0;
        timerContract = _timer;

        usdt = _usdt;
        settingContract = _settingContract; 

        ouroPrice = 800*(10**18);
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyOwner
        override
    {}

    /**
       * @dev pause: This method is used to Pause contract to transfer chain 
    
    */
    function pause() public{
        require(settingContract == msg.sender, NOT_AUTHORIZED);
        _pause();
    }

    /**
        * @dev unpause: This method is used to Unpause contract to transfer chain      
    */
    function unpause() public{
        require(settingContract == msg.sender, NOT_AUTHORIZED);
        _unpause();
    }

    // /**
    //     @dev Only Silver Chain manager and Gold Chain manager can create booster for user.  
    //     this method will pay all due upkeep amount of owner and 
    //     claim all amount of owner's chains   
    //     @param to Address of user
    //     @param _tokenId  Created Booster id

    // */
    function setTimer(address _timer) public onlyOwner{
        timerContract = _timer;
    }

    function getTimer() public view returns(address _timer){
        return timerContract;
    }

    function getDay() public view returns(uint256 _day){
        return ITimer(timerContract).getDay();
    }
    
    function buyBooster(address to) public returns(uint256 _tokenId){
        // require(msg.sender == silverChainManager || msg.sender == goldChainManager || msg.sender == owner(), NOT_AUTHORIZED);
        require(totalSupply <_maxSupply, MAX_SUPPLY_RECACHED);

        IERC20(usdt).transferFrom(to, address(this), ouroPrice);

        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
        lastBooster = tokenId;
        boosts[to].push(tokenId);
        totalSupply++;
        if(balanceOf(to)==0){
            lastDay[to] = ITimer(timerContract).getDay();
            purchaseDay[to] = ITimer(timerContract).getDay();
        }
        return tokenId;
    }

    function pushToArray(address to, uint256 tokenId) public onlyOwner{
        boosts[to].push(tokenId);
        lastDay[to] = ITimer(timerContract).getDay()-1;
    }

    // /**
    // @dev Only Silver Chain manager and Gold Chain manager can trnsfer booster for old user to new user account.  
    // this method will pay all due upkeep amount of owner and 
    // claim all amount of owner's chains   
    // @param from Address of old user
    // @param to Address of new user
    // @param tokenId Transfered Booster id

    // */
    // function transferBooster(address from, address to, uint256 tokenId) public{ /// commented after discussion with supervisor, client can transfer through Wallet so we'll pause transfer 
    //     require(ownerOf(tokenId) == from, NOT_NFT_OWNER);
    //     // require(msg.sender == silverChainManager || msg.sender == goldChainManager, NOT_AUTHORIZED);

    //     delete boosts[from];

    //     transferFrom(from, to, tokenId);
        
    //     boosts[to].push(tokenId);
    //     lastDay[to] = ITimer(timerContract).getDay();
    // }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize)internal override{
        if(paused())
        {
        	if(msg.sender == owner() || from == address(0)){
        	// if(msg.sender == silverChainManager || msg.sender == owner() || msg.sender == goldChainManager){
        
        	    super._beforeTokenTransfer(from, to, tokenId, 1);
        	}
        	else{
           	    revert("paused");
       		}
        }
        else {
            super._beforeTokenTransfer(from, to, tokenId, 1);
        }

    }

    ///////////////////////////// Getters & Setters
    function getUserBoosterDay(address _user)public view returns(uint256 _day){
        return lastDay[_user];
    }
    function getuserboostersDay(address user) public view returns(uint256){
        return lastDay[user];
    }
    function setUserBoosterDay(address _user, uint256 _day)public{
        require(msg.sender == silverChainManager || msg.sender == goldChainManager, NOT_AUTHORIZED);
        lastDay[_user] = _day;
    }

    function getBoosterPurchaseDay(address _user)public view returns(uint256 _day){
        return purchaseDay[_user];
    }
    
    function setBoosterPurchaseDay(address _user, uint256 _day)public{
        require(msg.sender == silverChainManager || msg.sender == goldChainManager, NOT_AUTHORIZED);
        purchaseDay[_user] = _day;
    }

    function getBoosterSellDay(address _user)public view returns(uint256 _day){
        return sellDay[_user];
    }
    
    function setBoosterSellDay(address _user, uint256 _day)public{
        require(msg.sender == silverChainManager || msg.sender == goldChainManager, NOT_AUTHORIZED);
        sellDay[_user] = _day;
    }
    /**
    * @dev Returns USDT Token address 
    @param _usdt USDT Token address 
    */
    function getUsdt() public view returns(address _usdt) {
        return usdt;
    }

    /**
    * @dev Sets USDT token address. Only setting contract can set this value   
    @param _usdt USDT Token address
    */
    function setUsdt(address _usdt) public {
        require(settingContract == msg.sender, NOT_AUTHORIZED);
        usdt = _usdt;
    }

    /**
    * @dev Returns price to create Booster.   
    @param _ouroPrice BorosBooster price
    */
    function getBoosterPrice() public view returns(uint256 _ouroPrice){
        return (ouroPrice);
    }

    /**
    * @dev Sets Booster price value. Only setting contract can set this value  
     @param _ouroPrice BorosBooster price
    */
    function setBoosterPrice(uint256 _ouroPrice) public {
        require(settingContract == msg.sender, NOT_AUTHORIZED);
        ouroPrice = _ouroPrice;
    }

    /**
    * @dev Returns Booster Ids of user     
    @param user User address
    @param userboosts Booster Id array
    */ 
    function getUserBoosters(address user) public view returns(uint256[] memory userboosts){
        return boosts[user];
    }

    /**
    * @dev Returns Max supply of boosters to create.     
    @param maxSupply Max supply of boosters
    */ 
    function getMaxSupply() public view returns(uint256 maxSupply){
        return _maxSupply;
    }

    /**
    * @dev Sets Max supply of boosters. Only setting contract can set this value   
    @param maxSupply Max supply to create
    */
    function setMaxSupply(uint256 maxSupply) public{
        require(settingContract == msg.sender, NOT_AUTHORIZED);
        _maxSupply = maxSupply;
    }
   
    /**
    * @dev Sets Silver chain manager address. Only Setting contract can call this method.     
    @param _silverChainManager Silver chain manager address
    */ 
    function setSilverChainManager(address _silverChainManager) public {
        require(settingContract == msg.sender, NOT_AUTHORIZED);
        silverChainManager = _silverChainManager;
    }

    /**
    * @dev Returns Silver chain manager contract address.     
    @param _silverChainManager Silver chain manager contract address
    */ 
    function getSilverChainManager() public view returns(address _silverChainManager){
           return silverChainManager;
    }
  
    /**
    * @dev Sets Gold chain manager address. Only Setting contract can call this method.     
    @param _goldChainManager Gold chain manager address
    */ 
    function setGoldChainManager(address _goldChainManager) public {
        require(settingContract == msg.sender, NOT_AUTHORIZED);
        goldChainManager = _goldChainManager;
    }

    /**
    * @dev Returns Gold chain manager contract address.     
    @param _goldChainManager Gold chain manager contract address
    */ 
    function getGoldChainManager() public view returns(address _goldChainManager){
        return goldChainManager;
    }
  
    /**
    * @dev Returns Setting contract address.
    @param _settingContract Setting contract address
    */  
    function getSettingContract() public view returns (address _settingContract) {
        return settingContract;
    }
    
    /**
    * @dev Sets Setting contract address. Only owner can set this value   
    @param _settingContract Setting Contract address
    */
    function setSettingContract(address _settingContract) public onlyOwner{
        settingContract = _settingContract;
    }
  
    /**
    * @dev Returns Last minted Booster Id.
    @param _lastBooster Booster Id
    */  
    function getLastBooster() public view returns(uint256 _lastBooster){
        return lastBooster;
    }
  
    /**
    * @dev Returns total Boosters minted till date.
    @param _totalSupply total boosters count
    */  
    function getTotalSupply() public view returns(uint256 _totalSupply){
        return totalSupply;
    }

    function setTotalSupply(uint256 _totalSupply) public {
        require(settingContract == msg.sender, NOT_AUTHORIZED);
        totalSupply = _totalSupply;
    }
////////////////////// Receive Methods //////////////////////////

    /**
    * @dev Returns any token balance of contract.   
    @param _tokenAddress Token contract address 
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
    @param tokenAddress Token Address 
    @param _destionation User address
    */
    function withdrawToken(address tokenAddress, address _destionation) public onlyOwner{
        uint256 tokenBalance = IERC20(tokenAddress).balanceOf(address(this));
        require(tokenBalance > 0, NO_TOKENS);
        IERC20(tokenAddress).transfer(_destionation, tokenBalance);
    }

    /**
    * @dev Withdraw currency balance from this contrat and can send to any address. Only Owner can call this method.   
    @param _destionation User address
    */
    function withdrawCurrency(address _destionation) public onlyOwner {
        require(address(this).balance > 0, NO_CURRENCY);
        payable(_destionation).transfer(address(this).balance);
    }

    receive() external payable {
        emit paymentRecieved(msg.sender, msg.value);
    }

    fallback() external payable {
        emit fallbackCalled(msg.sender, msg.value);
    }

  

}