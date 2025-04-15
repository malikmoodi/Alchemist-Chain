// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "../Interface/IERC20.sol";
import "../HelperContracts/SafeMath.sol";

contract AlxToken is
    Initializable,
    ERC20Upgradeable,
    PausableUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    event paymentRecieved(address sender, uint256 amount);
    event fallbackCalled(address sender, uint256 amount);
    address private settingContract;
    address private silverChainManager;
    address private goldChainManager;

    ///////////////////////////// Error variables //////////////////
    string constant NOT_AUTHORIZED = "ALX1";
    string constant WALLET_LIMIT_REACHED = "ALX2";
    string constant PAUSED = "ALX3";
    string constant NOT_SCM = "ALX4";

    constructor() {
        _disableInitializers();
    }

    /**
    * @dev Initialize: Deploy ALX Token and sets basic values. Tokens minted on user address
    */
    function initialize(address _settingContract) public initializer {
        __ERC20_init("ALX TOKEN", "ALX");
        __Pausable_init();
        __Ownable_init();
        __UUPSUpgradeable_init();
        settingContract = _settingContract;

        _mint(msg.sender, 100000 * 10**decimals());
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyOwner
    {}

    /**
    @dev This method mints tokens on caller's address. Only Silver Chain manager and Gold Chain manager can call this method.
    @param amount Amount of tokens to mint
    */  
    function distributeReward(uint256 amount) public {
        require(
            silverChainManager == msg.sender || goldChainManager == msg.sender, NOT_AUTHORIZED);
        _mint(msg.sender, amount);
    }


    ////////////////////////// Setters & Getters ///////////////////

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
