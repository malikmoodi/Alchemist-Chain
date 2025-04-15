// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "../Interface/IERC20.sol";
import "../HelperContracts/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract BROAlchemist is Initializable, OwnableUpgradeable, UUPSUpgradeable{
    using SafeMath for uint256;

    event paymentRecieved(address sender, uint256 amount);
    event fallbackCalled(address sender, uint256 amount);
    event FundTransfer(address cexAddress, uint256 amount);

    string constant NOT_AUTHORIZED = "ALBRO1";
    string constant NO_TOKENS = "ALBRO2";
    string constant NO_CURRENCY = "ALBRO3";
    string constant ADDRESS_ZERO = "ALBRO4";
    string constant NOT_CEX_ADDRESS = "ALBRO5";
    string constant CEX_ADDRESS_EXISTED = "ALBRO6";

    address private settingContract;
    address private liquidityHelper;
    address private usdt;
    address[] private cexAddresses;

    function initialize(address _usdt, address _settingContract) initializer public {
        __Ownable_init();
        __UUPSUpgradeable_init();

        settingContract = _settingContract;
        usdt = _usdt;
    }

    function _authorizeUpgrade(address newImplementation)internal onlyOwner override{}
   
   /////////////Main methods
    function shareFundWithCexs() public {
        require(msg.sender == liquidityHelper, NOT_AUTHORIZED);
        uint256 shareAmount = getTokenBalance(usdt).div(getCexAddressesLength());

        for(uint i; i < getCexAddressesLength(); i++){
            IERC20(usdt).transfer(cexAddresses[i], shareAmount);
            emit FundTransfer(cexAddresses[i], shareAmount); /// discuss for emit
        }
    }

    function addCexAddress(address _cexAddress) public onlyOwner{
        require(_cexAddress != address(0), ADDRESS_ZERO);
        bool _status;

        for(uint i; i < getCexAddressesLength(); i++){
            if(_cexAddress == cexAddresses[i]){
                _status = true;
                revert(CEX_ADDRESS_EXISTED);
            }
        }

        if(!_status){
            cexAddresses.push(_cexAddress);
        }
    }
    
    function removeCexAddress(address _cexAddress) public onlyOwner returns(bool _status){
        require(_cexAddress != address(0), ADDRESS_ZERO);
        
        for(uint i; i < getCexAddressesLength(); i++){
            if(_cexAddress == cexAddresses[i]){
                cexAddresses[i] = cexAddresses[cexAddresses.length-1];
                cexAddresses.pop();
                _status = true;
                break;
            }
        }

        if(_status){
            return true;
        }else{
            revert(NOT_CEX_ADDRESS);
        }
    }

    function removeAllCexAddress() public onlyOwner returns(bool _status){
        delete cexAddresses;
        if(getCexAddressesLength()== 0){
            return true;
        }
    }
   ////////////// Setters & Getters
    function setLiquidityHelper(address _liquidityHelper) public {
        require(settingContract == msg.sender, NOT_AUTHORIZED);
        liquidityHelper = _liquidityHelper;
    }

    function getLiquidityHelper() public view returns(address _liquidityHelper){
        return liquidityHelper;
    }

    function getCexAddresses() public view returns(address[] memory _cexAddresses){
        return cexAddresses;
    }

    function getUsdt()external view returns(address _usdt){
        return usdt;
    }

    function getCexAddressesLength() public view returns(uint256 _cexs){
        return cexAddresses.length;
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
        IERC20(_tokenAddress).transfer(_destionation, _amount);
    }

    /**
        * @dev Withdraw currency balance from this contrat and can send to any address. Only Owner can call this method.   
        @param _destionation User addres
        @param _amount Amount to withdraw
    */
    function withdrawCurrency(address _destionation, uint256 _amount) public onlyOwner {
        payable(_destionation).transfer(_amount);
    }

    receive() external payable {
        emit paymentRecieved(msg.sender, msg.value);
    }

    fallback() external payable {
        emit fallbackCalled(msg.sender, msg.value);
    }

}