// SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

import "../HelperContracts/SafeMath.sol";
import "../Interface/IManagers.sol";
import "../Interface/IERC20.sol";
import "../Interface/IChains.sol";
// import "../Interface/IBooster.sol";
// import "../Interface/IToken.sol";

// import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract TransmutationVault is Initializable, OwnableUpgradeable, UUPSUpgradeable{
    using SafeMath for uint256;

    event paymentRecieved(address sender, uint256 amount);
    event fallbackCalled(address sender, uint256 amount);

    struct TransmuteData{
        bytes32 transHash;
        uint256[] tokenIds;
        address user;
        bool redChain;
        bool platChain;
    }

    TransmuteData[] private transmuteDataArr;

    string constant NOT_AUTHORIZED = "TM1";
    string constant ROI_NOT_REACHED = "TM2";
    string constant FOUR_CHAINS_REQUIRED = "TM3";
    string constant FIVE_CHAINS_REQUIRED = "TM4";
    string constant OVERFLOW_PAGE = "TM5";
    string constant NO_TOKENS = "TM6";
    string constant NO_CURRENCY = "TM7";

    address private settingContract;
    address private usdt;
    address private silverChainAddress;
    address private goldChainAddress;
    address private silverChainManager;
    address private goldChainManager;
    // address private silverChainManager;
    address private liquidityHelper;

    uint256 private maxRoiLimit;
    uint256 private redChainPrice;
    uint256 private platChainPrice;

    uint256 private goldChainLimit;
    uint256 private silverChainLimit;

    constructor() {
        _disableInitializers();
    }
    /**
    * @dev Initialize: Deploy Alchemic Gold Chain and sets value of rewardsPerPeriod, rewardPeriod and perWalletLimit 
    *
    */
    function initialize(address _usdt, address _silverChainManager, address _silverChainAddress, 
                        address _goldChainAddress, address _goldChainManager, address _settingContract) public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();

        settingContract = _settingContract;
        silverChainAddress = _silverChainAddress;
        goldChainAddress = _goldChainAddress;
        silverChainManager = _silverChainManager;
        usdt = _usdt;
        goldChainManager = _goldChainManager;

        maxRoiLimit = 200;
        redChainPrice = 200*10**18;
        platChainPrice = 400*10**18;
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyOwner
    {}

    function transmuteSilverChains(uint256[] memory _tokenIds) public {
        require(_tokenIds.length == silverChainLimit, FOUR_CHAINS_REQUIRED);
        for(uint8 i = 0; i < _tokenIds.length; i++ ){
            uint256 roiPercent = IManagers(silverChainManager).calculateRoi(_tokenIds[i]);

            if(roiPercent < maxRoiLimit){
                revert(ROI_NOT_REACHED);
            }
        }

        // IERC20(usdt).transferFrom(msg.sender, address(this), redChainPrice);
        IERC20(usdt).transferFrom(msg.sender, liquidityHelper, redChainPrice);

        
        for(uint8 i = 0; i < _tokenIds.length; i++ ){
            IChains(silverChainAddress).burn(_tokenIds[i], msg.sender);
        }
        
        TransmuteData memory data = TransmuteData({
            transHash : getPrivateUniqueKey(msg.sender),
            tokenIds: _tokenIds,
            user : msg.sender,
            redChain: true,
            platChain:false
        });
        transmuteDataArr.push(data);
    }

    function transmuteGoldChains(uint256[] memory _tokenIds) public {
        require(_tokenIds.length == goldChainLimit, FIVE_CHAINS_REQUIRED);
        for(uint8 i = 0; i < _tokenIds.length; i++ ){
            uint256 roiPercent = IManagers(goldChainManager).calculateRoi(_tokenIds[i]);

            if(roiPercent < maxRoiLimit){
                revert(ROI_NOT_REACHED);
            }
        }

        // IERC20(usdt).transferFrom(msg.sender, address(this), platChainPrice);
        IERC20(usdt).transferFrom(msg.sender, liquidityHelper, platChainPrice);

        for(uint8 i = 0; i < _tokenIds.length; i++ ){
            IChains(goldChainAddress).burn(_tokenIds[i], msg.sender);
        }
        
        TransmuteData memory data = TransmuteData({
            transHash : getPrivateUniqueKey(msg.sender),
            tokenIds: _tokenIds,
            user : msg.sender,
            redChain: false,
            platChain:true
        });

        transmuteDataArr.push(data);
    }


    /**
     * @dev First in last out. Returns total number of Transmuted data of chains with pagination, e.g. if Transmuted data of chains count increased in hundreds then {getPaginatedTransmuteData} divide returned data of `transmuteDataArr` array and display it in multiple pages.
     * @param page Number of pages
     * @param size Total number of lockers addresses per page
     * @param paginatedData TransmuteData Data with pagination(in pages)
     */
    function getPaginatedTransmuteData(uint256 page, uint256 size) public view returns (TransmuteData[] memory paginatedData){
        uint256 ToSkip = page * size; //to skip
        uint256 count = 0;

        uint256 EndAt = transmuteDataArr.length > ToSkip + size
            ? ToSkip + size
            : transmuteDataArr.length;

        require(ToSkip < transmuteDataArr.length, OVERFLOW_PAGE);
        require(EndAt > ToSkip, OVERFLOW_PAGE);
        TransmuteData[] memory result = new TransmuteData[](EndAt - ToSkip);

        for (uint256 i = ToSkip; i < EndAt; i++) {
            result[count] = transmuteDataArr[(transmuteDataArr.length.sub(1)).sub(i)];
            count++;
        }
        return result;
    }

    function getPrivateUniqueKey(address user) private view returns (bytes32){
        return keccak256(abi.encodePacked(user, block.timestamp));
    }

    function getTransmuteArray() public view returns (TransmuteData[] memory transmuteArray){
        return transmuteDataArr;
    }

    function getTransmuteLength() public view returns (uint256 transmuteLength){
        return transmuteDataArr.length;
    }
   ////////////////////// Getters and Setters
    function setLiquidityHelper(address _liquidityHelper) public {
        require(settingContract == msg.sender, NOT_AUTHORIZED);
        liquidityHelper = _liquidityHelper;
    }

    function getLiquidityHelper() public view returns(address _liquidityHelper){
        return liquidityHelper;
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
    * @dev Returns Gold chain address 
    @param _goldChainAddress Gold chain address 
    */ 
    function getGoldChainAddress() public view returns(address _goldChainAddress) {
        return goldChainAddress;
    }

    /**
    * @dev Sets Gold chain address. Only setting contract can set this value   
    @param _goldChainAddress Gold chain address
    */
    function setGoldChainAddress(address _goldChainAddress) public{
        require(settingContract == msg.sender, NOT_AUTHORIZED);
        goldChainAddress = _goldChainAddress;
    }

    /**
    * @dev Returns Silver chain address 
    @param _silverChainAddress Silver chain address 
    */ 
    function getSilverChainAddress() public view returns(address _silverChainAddress) {
        return silverChainAddress;
    }

    /**
    * @dev Sets Silver chain address. Only setting contract can set this value   
    @param _silverChainAddress Silver chain address
    */
    function setSilverChainAddress(address _silverChainAddress) public {
        require(settingContract == msg.sender, NOT_AUTHORIZED);
        silverChainAddress = _silverChainAddress;
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
    
    function getGoldChainLimit() public view returns (uint256 _goldChainLimit) {
        return goldChainLimit;
    }
    
    function setGoldChainLimit(uint256 _goldChainLimit) public{
        require(settingContract == msg.sender, NOT_AUTHORIZED);
        goldChainLimit = _goldChainLimit;
    }

    function getSilverChainLimit() public view returns (uint256 _maxSilverChainLimit) {
        return silverChainLimit;
    }
    
    function setSilverChainLimit(uint256 _silverChainLimit) public{
        require(settingContract == msg.sender, NOT_AUTHORIZED);
        silverChainLimit = _silverChainLimit;
    }
    /**
    * @dev Returns max. ROI Limit.
    @param _maxRoiLimit ROI Limit
    */  
    function getRoiLimit() public view returns (uint256 _maxRoiLimit) {
        return maxRoiLimit;
    }
    
    /**
    * @dev Sets the value of max. ROI Limit. 
    @param _maxRoiLimit ROI Limit
    */
    function setRoiLimit(uint256 _maxRoiLimit) public{
        require(settingContract == msg.sender, NOT_AUTHORIZED);
        maxRoiLimit = _maxRoiLimit;
    } 

       
    /**
    * @dev Returns Price in usdt for 2 silver chains transmutation and to create 1 Scarlet Chains Red.
    @param _redChainPrice USDT price
    */  
    function getRedChainPrice() public view returns (uint256 _redChainPrice) {
        return redChainPrice;
    }
    
    /**
    * @dev Sets Price in usdt for 2 silver chains transmutation and to create Scarlet Chains Red.
    @param _redChainPrice ROI Limit
    */
    function setRedChainPrice(uint256 _redChainPrice) public{
        require(settingContract == msg.sender, NOT_AUTHORIZED);
        redChainPrice = _redChainPrice;
    } 

    /**
    * @dev Returns Price in usdt for 2 silver chains transmutation and to create 1 Scarlet Chains Red.
    @param _platChainPrice USDT price
    */  
    function getPlatChainPrice() public view returns (uint256 _platChainPrice) {
        return platChainPrice;
    }
    
    /**
    * @dev Sets Price in usdt for 2 silver chains transmutation and to create Scarlet Chains Red.
    @param _platChainPrice ROI Limit
    */
    function setPlatChainPrice(uint256 _platChainPrice) public{
        require(settingContract == msg.sender, NOT_AUTHORIZED);
        platChainPrice = _platChainPrice;
    } 
      
   /////////////////// Payment methods ////////////
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
        uint256 tokenBalance = IERC20(_tokenAddress).balanceOf(address(this));
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