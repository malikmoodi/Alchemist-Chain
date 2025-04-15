// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "../Interface/IBROAlchemist.sol";
import "../Interface/IERC20.sol";
import "../Interface/IUniswapV2Router02.sol";
import "../HelperContracts/SafeMath.sol";
import "./BROAlchemist.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract LiquidityHelper is Initializable, OwnableUpgradeable, UUPSUpgradeable{
    using SafeMath for uint256;

    event paymentRecieved(address sender, uint256 amount);
    event fallbackCalled(address sender, uint256 amount);
    event FundTransfer(address operatorAddress, uint256 amount);

    string constant NOT_AUTHORIZED = "ALQH1";
    string constant NO_TOKENS = "ALQH2";
    string constant NO_CURRENCY = "ALQH3";
    string constant SHARE_NOT_100 = "ALQH4";
    string constant NOT_CEX_ADDRESS = "ALQH5";
    string constant CEX_ADDRESS_EXISTED = "ALQH6";
    string constant ADDRESS_ZERO = "ALQH7";
    string constant OPERATOR_ADDRESS_EXISTED = "ALQH8";

    address private broContract;
    // address private feeOperator;
    address private uniPair;
    address private alcc;
    address private usdt;
    address private settingContract;
    
    IUniswapV2Router02 private uniRouter;

    uint8 private broShare;
    uint8 private liquidityShare;
    uint8 private treasuryShare;
    uint8 private feeShare;

    address private treasuryWallet;
    address[] private operatorArr;

    
    function initialize(address _alcc, address _usdt,  address _broContract, address _settingContract, address _treasuryWallet) initializer public {
        __Ownable_init();
        __UUPSUpgradeable_init();

        broContract = _broContract;
        alcc = _alcc;
        usdt = _usdt;
        settingContract = _settingContract;
        // feeOperator = _feeOperator; address _feeOperator,
        treasuryWallet = _treasuryWallet;


        liquidityShare = 80;
        feeShare = 5;
        treasuryShare = 5;
        broShare = 10;

        // uniRouter = IUniswapV2Router02(0xC6A32f7c1796E699f97D89A75DDD2C0e8Ca8358A);   //RLC mainnet Router
        // uniRouter = IUniswapV2Router02(0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3); // BSC Testnet
        uniRouter = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);   //BSC mainnet Router
    }

    function _authorizeUpgrade(address newImplementation)internal onlyOwner override{}
   /////////////Main methods
    function fundDistribution() public {
        uint256 usdtBalance = IERC20(usdt).balanceOf(address(this));
        
        uint256 _lqShare = (usdtBalance.mul(liquidityShare)).div(100);
        uint256 _broShare = (usdtBalance.mul(broShare)).div(100);
        uint256 _feeShare = (usdtBalance.mul(feeShare)).div(100);
        uint256 _treasuryShare = (usdtBalance.mul(treasuryShare)).div(100);
        
        addliquidity(_lqShare);
        IERC20(usdt).transfer(broContract, _broShare);
        IBROAlchemist(broContract).shareFundWithCexs();
        swapUsdtToBnb(_feeShare);
        IERC20(usdt).transfer(treasuryWallet, _treasuryShare);

        uint256 bnbBalance = address(this).balance;
        uint256 bnbShare = bnbBalance.div(operatorArr.length);
        for(uint i; i < operatorArr.length; i++){
            payable(operatorArr[i]).transfer(bnbShare);
            emit FundTransfer(operatorArr[i], bnbShare); /// discuss for emit
        }
    }

    function addliquidity(uint256 _lqShare)private {
        uint256 alccBalance = IERC20(alcc).balanceOf(address(this));

        IERC20(alcc).approve(address(uniRouter), alccBalance);
        IERC20(usdt).approve(address(uniRouter), _lqShare);
        uniRouter.addLiquidity(alcc, usdt, alccBalance, _lqShare, 0, 0, treasuryWallet, block.timestamp); /// lp token receipent
    }

    function swapUsdtToBnb(uint256 _feeShare) private  {
        address[] memory path = new address[](2);
        path[0] = usdt;
        path[1] = uniRouter.WETH();
        IERC20(usdt).approve(address(uniRouter), _feeShare);
        uniRouter.swapExactTokensForETH(_feeShare, 0, path, address(this), block.timestamp);

    }

    function addOperatorAddress(address _operatorAddress) public onlyOwner{
        require(_operatorAddress != address(0), ADDRESS_ZERO);
        bool _status;

        for(uint i; i < getOperatorAddressesLength(); i++){
            if(_operatorAddress == operatorArr[i]){
                _status = true;
                revert(OPERATOR_ADDRESS_EXISTED);
            }
        }

        if(!_status){
            operatorArr.push(_operatorAddress);
        }
    }
    
    function removeOperatorAddress(address _operatorAddress) public onlyOwner returns(bool _status){
        require(_operatorAddress != address(0), ADDRESS_ZERO);
        
        for(uint i; i < getOperatorAddressesLength(); i++){
            if(_operatorAddress == operatorArr[i]){
                operatorArr[i] = operatorArr[operatorArr.length-1];
                operatorArr.pop();
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
   ////////////// Setters & Getters
    
    function getOperatorAddressesLength() public view returns(uint256 _operators){
        return operatorArr.length;
    }
    function getOperatorArr() public view returns(address[] memory _operatorArr){
        return operatorArr;
    }
    // function setfeeOperator(address _feeOperator) public{
    //     require(settingContract == msg.sender, NOT_AUTHORIZED);
    //     feeOperator = _feeOperator;
    // }

    // function getFeeOperator() public view returns(address){
    //     return feeOperator;
    // }

    // function getPairAddress() public view returns(address){
    //     return address(uniPair);
    // }
    function setRouter(address _uniRouter) external  {
        require(settingContract == msg.sender, NOT_AUTHORIZED);
        uniRouter = IUniswapV2Router02(_uniRouter);   //BSC mainnet Router
    }

    function getRouter()external view returns(address _uniRouter){
        return address(uniRouter);
    }
    function setBROContract(address _broContract) external  {
        require(settingContract == msg.sender, NOT_AUTHORIZED);
        broContract = _broContract;
    }

    function getBROContract()external view returns(address){
        return broContract;
    }

    function setFundsPercentage(uint8 _liquidityShare, uint8 _feeShare, uint8 _treasuryShare, uint8 _broShare) external  {
        require(settingContract == msg.sender, NOT_AUTHORIZED);
        require((_liquidityShare + _treasuryShare + _feeShare + _broShare) == 100, SHARE_NOT_100);
        
        liquidityShare = _liquidityShare;
        feeShare = _feeShare;
        treasuryShare = _treasuryShare;
        broShare = _broShare;
    }

    function getFundsPercentage()external view returns(uint8 _liquidityShare, uint8 _feeShare, uint8 _treasuryShare, uint8 _broShare){
        return (liquidityShare, feeShare, treasuryShare, broShare);
    }

    function getUsdt()external view returns(address _usdt){
        return usdt;
    }

    function getAlcc()external view returns(address _alcc){
        return alcc;
    }
    
    function setAlcc(address _alcc)external onlyOwner{
        alcc = _alcc;
    }

    function setUsdt(address _usdt)external onlyOwner{
        usdt = _usdt;
    }

    function setTreasueryWallet(address _treasuryWallet) external {
        require(settingContract == msg.sender, NOT_AUTHORIZED);
        treasuryWallet = _treasuryWallet;
    }

    function getTreasueryWallet()external view returns(address){
        return treasuryWallet;
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
