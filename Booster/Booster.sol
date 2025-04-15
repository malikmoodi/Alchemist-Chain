// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "../Interface/IERC721.sol";
import "../HelperContracts/SafeMath.sol";
import "../Interface/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

contract Ouroboros is Initializable, ERC721Upgradeable, PausableUpgradeable, OwnableUpgradeable, UUPSUpgradeable  {
    using CountersUpgradeable for CountersUpgradeable.Counter;
    
    event paymentRecieved(address sender, uint256 amount);
    event fallbackCalled(address sender, uint256 amount);

    CountersUpgradeable.Counter private _tokenIdCounter;

    address private silverChainManager;
    address private goldChainManager;
    address private settingContract;

    uint256 private ouroborosPrice; 
    uint256 private _maxSupply; 
    uint256 private lastBooster;
    uint256 private totalSupply;


    mapping (address => uint256[]) private boosts; 

    string constant NOT_AUTHORIZED = "OUR1";
    string constant MAX_SUPPLY_RECACHED = "OUR2";
    string constant NOT_TOKEN_OWNER = "OUR3";
    string constant PAUSED = "OUR4";


    constructor() {
          _disableInitializers();
    }
    
    /**
    * @dev Initialize: Deploy Alchemic Gold Chain Manager and set the basic values 
    *
    */
    function initialize(address _settingContract) initializer public {
        __ERC721_init("Ouroboros", "OUR");
        __Pausable_init();
        __Ownable_init();
        __UUPSUpgradeable_init();
        _maxSupply = 200;
        totalSupply = 0;

        settingContract = _settingContract; 

        ouroborosPrice = 750*10**18;
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

    /**
    @dev Only Silver Chain manager and Gold Chain manager can create booster for user.  
    this method will pay all due upkeep amount of owner and 
    claim all amount of owner's chains   
    @param to Address of user
    @param _tokenId  Created Booster id

    */
    function buyBooster(address to) public returns(uint256 _tokenId){
        require(msg.sender == silverChainManager || msg.sender == goldChainManager || msg.sender == owner(), NOT_AUTHORIZED);
        require(totalSupply<_maxSupply, MAX_SUPPLY_RECACHED);

        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
        lastBooster = tokenId;
        boosts[to].push(tokenId);
        totalSupply++;
        return tokenId;
    }

    /**
    @dev Only Silver Chain manager and Gold Chain manager can trnsfer booster for old user to new user account.  
    this method will pay all due upkeep amount of owner and 
    claim all amount of owner's chains   
    @param from Address of old user
    @param to Address of new user
    @param tokenId Transfered Booster id

    */
    function transferBooster(address from, address to, uint256 tokenId) public{
        require(msg.sender == silverChainManager || msg.sender == goldChainManager, NOT_AUTHORIZED);

        delete boosts[from];

        transferFrom(from, to, tokenId);
        
        boosts[to].push(tokenId);

    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize)internal override{
        if(paused())
        {
        	if(msg.sender == silverChainManager || msg.sender == owner() || msg.sender == goldChainManager){
        
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
    * @dev Withdraw any token balance from this contrat and can send to any address. Only Owner can call this method.   
    @param tokenAddress Token Address 
    @param _destionation User address
    */
    function withdrawToken(address tokenAddress, address _destionation) public onlyOwner{
        uint256 tokenBalance = IERC20(tokenAddress).balanceOf(address(this));
        require(tokenBalance > 0, "NO_TOKENS");
        IERC20(tokenAddress).transfer(_destionation, tokenBalance);
    }

    /**
    * @dev Withdraw currency balance from this contrat and can send to any address. Only Owner can call this method.   
    @param _destionation User address
    */
    function withdrawCurrency(address _destionation) public onlyOwner {
        require(address(this).balance > 0, "NO_CURRENCY");
        payable(_destionation).transfer(address(this).balance);
    }

    receive() external payable {
        emit paymentRecieved(msg.sender, msg.value);
    }

    fallback() external payable {
        emit fallbackCalled(msg.sender, msg.value);
    }

  

}    

/*
contract Ouroboros is Initializable, ERC721Upgradeable, PausableUpgradeable, OwnableUpgradeable, UUPSUpgradeable  {
    using CountersUpgradeable for CountersUpgradeable.Counter;

    CountersUpgradeable.Counter private _tokenIdCounter;

    modifier onlyManager{
        require(msg.sender == manager, NOT_AUTHORIZED);
        _;
    }

    address private settingContract;
    address private manager;
    uint256 private _maxSupply; 
    uint256 private lastBooster;
    uint256 private totalSupply;
    mapping (address => uint256[]) private boosts; 

    string constant NOT_AUTHORIZED = "OUR1";
    string constant MAX_SUPPLY_RECACHED = "OUR2";
    string constant NOT_TOKEN_OWNER = "OUR3";
    string constant PAUSED = "OUR4";


    constructor() {
          _disableInitializers();
    }
    
    function initialize(address _manager) initializer public {
        __ERC721_init("Ouroboros", "OUR");
        __Pausable_init();
        __Ownable_init();
        __UUPSUpgradeable_init();
        manager = _manager;
        _maxSupply = 250;
        totalSupply = 0;
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyOwner
        override
    {}

    function setManager(address _manager) public {
        require(owner() == msg.sender || settingContract == msg.sender, NOT_AUTHORIZED);
        manager = _manager;
    }

    function getManager() public view returns(address _manager){
        return manager;
    }

    function getSettingContract() public view returns (address _settingContract) {
        return settingContract;
    }

    function setSettingContract(address _settingContract) public onlyOwner{
        settingContract = _settingContract;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function getMaxSupply() public view returns(uint256){
        return _maxSupply;
    }

    function setMaxSupply(uint256 maxSupply) public{
        require(owner() == msg.sender || settingContract == msg.sender, NOT_AUTHORIZED);

         _maxSupply = maxSupply;
    }

    function getBoosts(address user) public view returns(uint256[] memory userboosts){
        return boosts[user];
    }

    function buy(address to) public onlyManager returns(uint256 token){
        require(totalSupply<_maxSupply, MAX_SUPPLY_RECACHED);
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
        lastBooster = tokenId;
        boosts[to].push(tokenId);
        totalSupply++;
        return tokenId;
    }

    function getlastBooster() public view returns(uint256){
        return lastBooster;
    }

    // function burn(uint256 tokenId, address user) public onlyManager{
    //     require(ownerOf(tokenId)==user, NOT_TOKEN_OWNER);
    //     uint256[] storage boosters = boosts[user];
    //     uint tokenindex;
    //     for(uint i =0 ; i < boosters.length; i++){
    //         if(tokenId == boosters[i])
    //         {
    //             tokenindex = i;
    //             break;
    //         }
    //     }
    //     removefromArray(tokenindex, user);
    //     _burn(tokenId);
    //     totalSupply--;
    // }


    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        override
    {
        if(paused())
        {
        	if(msg.sender == manager){
            

        
        	super._beforeTokenTransfer(from, to, tokenId);
        	}
        	else{
           	 	revert(PAUSED);
       		 }
        }
        else {
            super._beforeTokenTransfer(from, to, tokenId);
        }
    }

    // function removefromArray(uint index, address owner) private {
    //     uint256[] storage boosters = boosts[owner];
    //     boosters[index]= boosters[boosters.length-1];
    //     boosters.pop();
    //     boosts[owner] = boosters;
    // }

     function getTotalSupply() public view returns(uint256){
        return totalSupply;
    }
}    
*/