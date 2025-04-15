// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./Ownable.sol";
import "./SafeMath.sol";
import "./IERC20.sol";
import "./IUniswapV2Router02.sol";
import "./IUniswapV2Factory.sol";
import "./IUniswapV2Pair.sol";

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract MainBRO is Initializable, OwnableUpgradeable, UUPSUpgradeable{
    using SafeMath for uint256;

    event paymentRecieved(address sender, uint256 amount);
    event fallbackCalled(address sender, uint256 amount);
    
    IUniswapV2Router02 private uniRouter;
    IUniswapV2Factory private uniFactory;
    address private uniPair;
    address private usdt;
    address private scar;
    address private operator; 

    address private miscAddress;
    address private marketingAddress;
    address private BuyBack1;
    address private BuyBack2;
    address private Buyback3;
    address private BuyBack4;

    uint256 private marketingSharePercent; 
    uint256 private miscSharePercent; 
    uint256 private broSharePercent; 
    uint256 private liquiditySharePercent; 


    constructor() {
        _disableInitializers();
    }

    function initialize(address _scar, address _usdt, address _miscAddress, address _marketingAddress) initializer public {
        __Ownable_init();
        __UUPSUpgradeable_init();
        scar = _scar;
        usdt = _usdt;

        miscAddress = _miscAddress;
        marketingAddress = _marketingAddress;

        BuyBack1 =  0xe274E1F3F7814085C12D617BE6aBD143D4f680Db;
        BuyBack2 =  0xD3B98b7849c0C33c407b29Cac04C305AaEe593D0;
        Buyback3 =  0x89bB483251409c791135414De552F5CcA4815bf3;
        BuyBack4 =  0x11904E491D6A8C637a341E7EB351b17197a061FB;

        marketingSharePercent = 5;
        miscSharePercent = 5;
        broSharePercent = 10;
        liquiditySharePercent = 80;

        // uniRouter = IUniswapV2Router02(0x5dC5431D67cA080b7c4bf7CB77f1B3e6FeD0F1AC);
        uniRouter = IUniswapV2Router02(0xC6A32f7c1796E699f97D89A75DDD2C0e8Ca8358A);   //RLC mainnet Router

        uniFactory = IUniswapV2Factory(uniRouter.factory());
        uniPair = uniFactory.getPair(scar, usdt);
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyOwner
        override
    {}

    function liquidityHelper_() public {
        uint256 tokenFee = IERC20(usdt).balanceOf(address(this));

        uint256 liquidityShare = (tokenFee.mul(liquiditySharePercent)).div(100);
        uint256 marketingShare = (tokenFee.mul(marketingSharePercent)).div(100);
        uint256 miscShare = (tokenFee.mul(miscSharePercent)).div(100);
        uint256 broShare = (tokenFee.mul(broSharePercent)).div(100);

        IERC20(usdt).transfer(miscAddress, miscShare);
        IERC20(usdt).transfer(marketingAddress, marketingShare);
        transferToBuyBacks(broShare);
        
        addliquidity(liquidityShare);
    }
    
    function transferToBuyBacks(uint256 _shareAmount) private {
        uint256 shareAmountDiv4 = _shareAmount.div(4);
        IERC20(usdt).transfer(BuyBack1, shareAmountDiv4);
        IERC20(usdt).transfer(BuyBack2, shareAmountDiv4);
        IERC20(usdt).transfer(Buyback3, shareAmountDiv4);
        IERC20(usdt).transfer(BuyBack4, shareAmountDiv4); 
    }
    // 80% LQ 5% Marketing 5% Misc 10% B-ro?
    function addliquidity(uint256 _liquidityShare)private {
        uint256 scrAmount = IERC20(scar).balanceOf(address(this));
        // uint256 usdtAmount = IERC20(usdt).balanceOf(address(this));
        IERC20(scar).approve(address(uniRouter), scrAmount);
        IERC20(usdt).approve(address(uniRouter), _liquidityShare);
        uniRouter.addLiquidity(scar,usdt,scrAmount,_liquidityShare,0,0,miscAddress,block.timestamp);
    }



///////////// Setters & Getters
    function setSharePercent(uint256 _marketingSharePercent, uint256 _miscSharePercent, uint256 _broSharePercent, uint256 _liquiditySharePercent) public onlyOwner{
        require(_marketingSharePercent.add(_miscSharePercent.add(_broSharePercent.add(_liquiditySharePercent))) == 100, "Not equal to 100");
        marketingSharePercent = _marketingSharePercent;        
        miscSharePercent = _miscSharePercent;        
        broSharePercent = _broSharePercent;
        liquiditySharePercent = _liquiditySharePercent;
    }
    
    function getSharePercent() public view returns(uint256 _marketingSharePercent, uint256 _miscSharePercent, uint256 _broSharePercent, uint256 _liquiditySharePercent){
        return (
            marketingSharePercent,             
            miscSharePercent, 
            broSharePercent, 
            liquiditySharePercent);
    }
    
    function setBuyBacks(address _buyBack1, address _buyBack2, address _buyBack3, address _buyBack4) public onlyOwner{
        BuyBack1 = _buyBack1;        
        BuyBack2 = _buyBack2;        
        Buyback3 = _buyBack3;
        BuyBack4 = _buyBack4;
    }
    
    function getBuyBacks() public view returns(address _buyBack1, address _buyBack2, address _buyBack3, address _buyBack4){
        return (
            BuyBack1,             
            BuyBack2, 
            Buyback3, 
            BuyBack4);
    }

    function setOperator(address _operator) public onlyOwner{
        operator = _operator;
    }

    function getOperator() public view returns(address){
        return operator;
    }

    function getPairAddress() public view returns(address){
        return address(uniPair);
    }

    function setMarketingAddress(address _marketingAddress) external onlyOwner {
        marketingAddress = _marketingAddress;
    }

    function getMarketingAddress()external view returns(address){
        return marketingAddress;
    }

    function setMiscAddress(address _miscAddress) external onlyOwner {
        miscAddress = _miscAddress;
    }

    function getMiscAddress()external view returns(address){
        return miscAddress;
    }

    function getUsdt()external view returns(address _usdt){
        return usdt;
    }

    function getScar()external view returns(address _scar){
        return scar;
    }

//////////////////////// Payment methods
    function withdrawToken(address _tokenAddress, address destination, uint256 amount) public onlyOwner{
        require(IERC20(_tokenAddress).balanceOf(address(this)) > 0, "NO_TOKEN");
        IERC20(_tokenAddress).transfer(destination, amount);
    }


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