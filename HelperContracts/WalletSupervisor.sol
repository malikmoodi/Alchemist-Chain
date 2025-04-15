//SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "./SafeMath.sol";
import "../Interface/IERC20.sol";

// import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";

contract WalletSupervisor is Initializable, OwnableUpgradeable, UUPSUpgradeable{
    using SafeMath for uint256;
    event paymentRecieved(address indexed sender, uint256 amount);
    event fallbackCalled(address indexed sender, uint256 amount);
    event IncreaseWalletAdded(address indexed sender, address chain, uint256 maxWalletLength);
    event DecreaseWalletAdded(address indexed sender, address chain, uint256 maxWalletLength);
   ///////////////Variables 
    address private silverChainAddress;
    address private goldChainAddress;
    address private settingContract;
    address private timerContract;

    uint32 private maxWalletUser;
    uint32 private maxChains;

    address[] private maxUsersArray;
    mapping (address => bool) private maxUserBool;     
    mapping (address => uint32) private usersChain;     
   ///////////////////Errors
    string constant NOT_AUTHORIZED = "WS1";
    string constant NO_TOKENS = "WS2";
    string constant NO_CURRENCY = "WS3";
    string constant REACHED_MAX_CHAINS = "WS4";
    string constant CANNOT_MAKE_MAX_CHAINS = "WS5";
    string constant OVERFLOW_PAGE = "WS6";
   //////////////// Initialize Methods
    function _authorizeUpgrade(address newImplementation)internal override onlyOwner{}

    constructor() {
        _disableInitializers();
    }

    /**
        *
    */
    function initialize(address _settingContract, uint32 _maxWalletUser, uint32 _maxChains) public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
        settingContract = _settingContract;

        maxWalletUser = _maxWalletUser;
        maxChains = _maxChains;
    }

   ////////////// Methods
    function increaseChainCount(address _user)public{
        require(msg.sender == silverChainAddress || msg.sender == goldChainAddress, NOT_AUTHORIZED);
        require(usersChain[_user] < maxChains, REACHED_MAX_CHAINS);
        if(maxUsersArray.length < maxWalletUser){
            usersChain[_user]++;
            if(usersChain[_user] == maxChains){
                maxUsersArray.push(_user);
                maxUserBool[_user] = true;
                emit IncreaseWalletAdded(_user, msg.sender, maxUsersArray.length);
            }
        }else{
            require(usersChain[_user] < (maxChains - 1), CANNOT_MAKE_MAX_CHAINS);
            usersChain[_user]++;
        }
    }

    function decreaseChainCount(address _user)public{
        require(msg.sender == silverChainAddress || msg.sender == goldChainAddress, NOT_AUTHORIZED);
        usersChain[_user]--;
        if(maxUserBool[_user]){
            for(uint256 i; i < maxUsersArray.length; i++){
                if(maxUsersArray[i] == _user){
                    maxUsersArray[i] = maxUsersArray[maxUsersArray.length - 1]; 
                    maxUsersArray.pop();
                    break;
                }
            }
            delete maxUserBool[_user];
            emit DecreaseWalletAdded(_user, msg.sender, maxUsersArray.length);
        }
    }
   //////////////Getters and Setters
    /**
     * @dev First in last out. Returns total address with pagination, e.g. if addresses count increased in hundreds then {getPaginatedMaxWallets} 
        divide returned data of `maxUsersArray` array and display it in multiple pages.
     * @param page Number of pages
     * @param size Total number of lockers addresses per page
     * @param _maxWallet TransmuteData Data with pagination(in pages)
    */
    function getPaginatedMaxWallets(uint256 page, uint256 size) public view returns (address[] memory _maxWallet){
        uint256 ToSkip = page * size; //to skip
        uint256 count = 0;

        uint256 EndAt = maxUsersArray.length > ToSkip + size
            ? ToSkip + size
            : maxUsersArray.length;

        require(ToSkip < maxUsersArray.length, OVERFLOW_PAGE);
        require(EndAt > ToSkip, OVERFLOW_PAGE);
        address[] memory result = new address[](EndAt - ToSkip);

        for (uint256 i = ToSkip; i < EndAt; i++) {
            result[count] = maxUsersArray[(maxUsersArray.length.sub(1)).sub(i)];
            count++;
        }
        return result;
    }    

    function getUserChainsCount(address _user)public view returns(uint32 _chainCount){
        return usersChain[_user];
    }

    function getMaxWalletArray()public view returns(uint256 _maxUsersCount){
        return maxUsersArray.length;
    }

    function checkMaxWallet(address _user)public view returns(bool _maxWallet){
        return maxUserBool[_user];
    }

    function getMaxChains() public view returns (uint32 _maxChains) {
        return maxChains;
    }

    function setMaxChains(uint32 _maxChains) public {
        require(settingContract == msg.sender, NOT_AUTHORIZED);
        maxChains = _maxChains;
    }

    function getMaxWalletUser() public view returns (uint32 _maxWalletUser) {
        return maxWalletUser;
    }

    function setMaxWalletUser(uint32 _maxWalletUser) public {
        require(settingContract == msg.sender, NOT_AUTHORIZED);
        maxWalletUser = _maxWalletUser;
    }
 
    function getSettingContract() public view returns (address _settingContract) {
        return settingContract;
    }

    function setSettingContract(address _settingContract) public onlyOwner{
        settingContract = _settingContract;
    }

    function getSilverChainAddress() public view returns(address _silverChainAddress) {
        return silverChainAddress;
    }

    function setSilverChainAddress(address _silverChainAddress) public{
        require(settingContract == msg.sender, NOT_AUTHORIZED);
        silverChainAddress = _silverChainAddress;
    }

    function getGoldChainAddress() public view returns(address _goldChainAddress) {
        return goldChainAddress;
    }

    function setGoldChainAddress(address _goldChainAddress) public{
        require(settingContract == msg.sender, NOT_AUTHORIZED);
        goldChainAddress = _goldChainAddress;
    }

   /////////////Payment methods
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