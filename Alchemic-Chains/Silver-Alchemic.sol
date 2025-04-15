// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "../Interface/IERC721.sol";
import "../Interface/IManagers.sol";
import "../Interface/IERC20.sol";
import "../Interface/ITimer.sol";
import "../Interface/IWalletSupervisor.sol";
import "../HelperContracts/SafeMath.sol";

contract SilverChainAlchemic is Initializable, ERC721Upgradeable, PausableUpgradeable, OwnableUpgradeable, UUPSUpgradeable{
    using CountersUpgradeable for CountersUpgradeable.Counter;
    using SafeMath for uint256;

    event paymentRecieved(address sender, uint256 amount);
    event fallbackCalled(address sender, uint256 amount);

    struct chainDetail {
        uint256 id;
        string name;
        uint256 totalClaimedAmount;
        uint256 lastClaimTime;
        uint256 lastClaimTimeBlockStamp;
        uint256 timeOfCreation;
        uint256 timeOfCreationBlockStamp;
    }

    struct userSilverChainList {
        uint256[] chains;
        uint256 totalClaimedAmount;
        uint256 lastClaimTime;
    }

    CountersUpgradeable.Counter private _tokenIdCounter;
    uint256 private rewardsPerPeriod;
    uint256 private rewardPeriod; 
    uint256 private perWalletLimit; 

    address private silverChainManager;
    address private goldChainManager;
    address private settingContract;
    address private timerContract;
    address private walletSupervisor;

    mapping(address => userSilverChainList) private userChainList; 
    mapping(uint256 => chainDetail) private chainDetails;

   ///////////////////////////// Error variables //////////////////
    string constant NOT_AUTHORIZED = "ACS1";
    string constant WALLET_LIMIT_REACHED = "ACS2";
    string constant PAUSED = "ACS3";
    string constant NOT_MANAGER = "ACS4";
   /////////////////////////////////////////
    constructor() {
        _disableInitializers();
    }

    /**
        * @dev Initialize: Deploy Alchemic Silver Chain and sets value of rewardsPerPeriod, rewardPeriod and perWalletLimit 
        *
        */
    function initialize(address _settingContract, address _timer, address _walletSupervisor) public initializer {
        __ERC721_init("ALCHEMIST CHAINS - Silver", "ALCC-S");
        __Pausable_init();
        __Ownable_init();
        __UUPSUpgradeable_init();
        
        settingContract = _settingContract;
        timerContract = _timer;
        walletSupervisor = _walletSupervisor;

        rewardsPerPeriod = 4*10**17;
        rewardPeriod = 5 minutes;
        perWalletLimit = 4;
    }

    /**
        * @dev createChain: Only Silver chain manager can call this method. Saves detail of Chain against user address and chain token Id. 
        *@param  to Address of user 
        *@param  name Name of chain
        *
    */
    function createChain(address to, string memory name)public returns (uint256 _tokenId){
        require(silverChainManager == msg.sender || goldChainManager == msg.sender, NOT_MANAGER);
        require(userChainList[to].chains.length < perWalletLimit, WALLET_LIMIT_REACHED);
        
        IWalletSupervisor(walletSupervisor).increaseChainCount(to);
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
        userChainList[to].chains.push(tokenId);
        chainDetails[tokenId].id = tokenId;
        chainDetails[tokenId].name = name;
        chainDetails[tokenId].lastClaimTime = ITimer(timerContract).getDay();
        chainDetails[tokenId].lastClaimTimeBlockStamp = block.timestamp;
        chainDetails[tokenId].totalClaimedAmount = 0;
        chainDetails[tokenId].timeOfCreation = ITimer(timerContract).getDay();
        chainDetails[tokenId].timeOfCreationBlockStamp = block.timestamp;

        return tokenId;
    }

   /////////////////////// Helper Methods //////////////////////////

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
        * @dev Claims reward of chain, and update last claim time of chain and total claim amount   
        @param tokenId Token ID of chain
        @param amount amount to be claim
    */
    function claimRewardsToken(uint256 tokenId, uint256 amount)public{
        require(
            _exists(tokenId),
            "ASC: approved query for nonexistent token"
        );

        chainDetails[tokenId].totalClaimedAmount += amount;
        chainDetails[tokenId].lastClaimTime = ITimer(timerContract).getDay();
        chainDetails[tokenId].lastClaimTimeBlockStamp = block.timestamp;
    }

    /**
        * @dev Calculates reward of chain, it calculates reward from last claim time to present time     
        @param tokenId Token ID of chain
        @param rewards Reward amount of chain
    */
    function calculateRewardsToken(uint256 tokenId) public view returns (uint256 rewards){
        require(
            _exists(tokenId),
            "ASC: approved query for nonexistent token"
        );
        rewards = 0;
        chainDetail memory detail = chainDetails[tokenId];
        uint256 timeSinceClaim = (ITimer(timerContract).getDay().sub(detail.lastClaimTime)); ///read here
            // .div(rewardPeriod);
        rewards = rewardsPerPeriod.mul(timeSinceClaim);
        return rewards;
    }

    /**
        * @dev This method can burn chain, and remove it from User chain list array. Only Managers or owner can burn chain     
        @param tokenId Token ID of chain
        @param owner Owner of chain
    */
    function burn(uint256 tokenId, address owner) public {
        require(ownerOf(tokenId) == owner || silverChainManager == msg.sender || goldChainManager == msg.sender, NOT_AUTHORIZED);
        IWalletSupervisor(walletSupervisor).decreaseChainCount(owner);
        uint256[] storage userchain = userChainList[owner].chains;
        uint256 tokenIndex;
        for (uint256 i = 0; i < userchain.length; i++) {
            if (tokenId == userchain[i]) {
                tokenIndex = i;
                break;
            }
        }
        _burn(tokenId);
        removefromArray(tokenIndex, owner);
    }

    function removefromArray(uint256 index, address owner) private {
        uint256[] storage userchain = userChainList[owner].chains;
        userchain[index] = userchain[userchain.length.sub(1)];
        userchain.pop();
        userChainList[owner].chains = userchain;
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyOwner
    {}

    function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize)internal override{
        if(paused())
        {
        	if(msg.sender == silverChainManager || msg.sender == goldChainManager || msg.sender == owner()){
        
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

   ////////////////////////// Setters & Getters ///////////////////
    
    function getWalletSupervisor() public view returns (address _walletSupervisor) {
        return walletSupervisor;
    }
    
    function setWalletSupervisor(address _walletSupervisor) public{
        require(settingContract == msg.sender, NOT_AUTHORIZED);
        walletSupervisor = _walletSupervisor;
    }

    /**
    * @dev Returns Setting contract address.     
    @param _settingContract Setting contract address
    */   
    function getSettingContract() public view returns (address _settingContract) {
        return settingContract;
    }
    /**
    * @dev Sets Setting contract address.Only owner can call this method.     
    @param _settingContract Setting contract address
    */ 
    function setSettingContract(address _settingContract) public onlyOwner{
        settingContract = _settingContract;
    }

    /**
    * @dev Returns Gold chain manager contract address.     
    @param _goldChainManager Gold chain manager contract address
    */   
    function getGoldChainManager() public view returns (address _goldChainManager) {
        return goldChainManager;
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
    * @dev Returns Silver chain manager contract address.     
    @param _silverChainManager Silver chain manager contract address
    */ 
    function getSilverChainManager() public view returns (address _silverChainManager) {
        return silverChainManager;
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
    @param _timerContract Silver chain manager contract address
    */ 
    function getTimerContract() public view returns (address _timerContract) {
        return timerContract;
    }

    /**
    * @dev Sets Silver chain manager address. Only Setting contract can call this method.     
    @param _timerContract Silver chain manager address
    */ 
    function setTimerContract(address _timerContract) public {
        require(settingContract == msg.sender, NOT_AUTHORIZED);
        timerContract = _timerContract;
    }
    /**
    * @dev Returns wallet limit of silver chain, User can create silver chains upto this limit.      
    @param _walletLimit Wallet limit
    */ 
    function getWalletLimit() public view returns (uint256 _walletLimit) {
        return perWalletLimit;
    }

    /**
    * @dev Sets wallet limit of silver chain, User can create silver chains upto this limit.
    Only Setting contract can call this method.   
    @param _walletLimit Wallet limit
    */ 
    function setWalletLimit(uint256 _walletLimit) public {
        require(settingContract == msg.sender, NOT_AUTHORIZED);
        perWalletLimit = _walletLimit;
    }

    /**
    * @dev Returns last claim time of chain. Chain(token id) must exist other wise it revert error.     
    @param _tokenId Token ID of chain
    */ 
    function getLastClaimtime(uint256 _tokenId)
        public
        view
        returns (uint256 _lastClaimTime)
    {
        require(
            _exists(_tokenId),
            "ASC: approved query for nonexistent token"
        );
        return chainDetails[_tokenId].lastClaimTime;
    }

    /**
    * @dev Returns User's chain details. Chain token ids, total claimed amount, last claim time.     
    @param user User address, owner of chains
    */ 
    function getUserDetails(address user)
        public
        view
        returns (userSilverChainList memory)
    {
        return userChainList[user];
    }

    /**
    * @dev Returns specific chain's detail. Chain's name, total claimed amount, last claim time and time of creation.     
      @param tokenId Token id of chain

    */ 
    function getChainDetails(uint256 tokenId) public view returns (chainDetail memory) {
        return chainDetails[tokenId];
    }

    /**
    * @dev Returns specific chain's total claimed amount.     
      @param tokenId Token id of chain
      @param _claimedAmount Total claimed amount

    */ 
    function getTotalClaimAmount(uint256 tokenId) public view returns (uint256 _claimedAmount){
        return chainDetails[tokenId].totalClaimedAmount;
    }
    /**
    * @dev Returns User chains count.     
    @param user User address, owner of chains

    */ 
    function getUserChains(address user)
        public
        view
        returns (uint256[] memory chains)
    {
        return userChainList[user].chains;
    }

    /**
    * @dev Sets reward period of Silver chain in days.
    Only Setting contract can call this method.   
    @param _rewardPeriod Wallet limit
    */
    function setRewardPeriod(uint256 _rewardPeriod) public {
        require(settingContract == msg.sender, NOT_AUTHORIZED);
        rewardPeriod = _rewardPeriod;
    }

    /**
    * @dev Returns reward period of Silver chain in days      
    @param _rewardPeriod Reward period 

    */ 
    function getRewardPeriod() public view returns(uint256 _rewardPeriod) {
        return rewardPeriod ;
    }

    /**
    * @dev Sets reward amount per period of Silver chain.
    Only Setting contract can call this method.   
    @param reward Reward per period
    */
    function setRewardPerPeriod(uint256 reward) public {
        require(settingContract == msg.sender, NOT_AUTHORIZED);
        rewardsPerPeriod = reward;
    }
    /**
    * @dev Returns reward amount per period of Silver chain.     
    @param _rewardsPerPeriod Reward per period

    */ 
    function getRewardPerPeriod()
        public
        view
        returns (uint256 _rewardsPerPeriod)
    {
        return rewardsPerPeriod;
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
