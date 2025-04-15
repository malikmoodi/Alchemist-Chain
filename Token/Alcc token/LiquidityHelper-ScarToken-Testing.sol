// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./Ownable.sol";

import "./IERC20.sol";
import "./IUniswapV2Router02.sol";
import "./IUniswapV2Factory.sol";
import "./IUniswapV2Pair.sol";

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract LiquidityHelper is Initializable, OwnableUpgradeable, UUPSUpgradeable{
    event paymentRecieved(address sender, uint256 amount);
    event fallbackCalled(address sender, uint256 amount);
    
    IUniswapV2Router02 private uniRouter;
    IUniswapV2Factory private uniFactory;
    address private uniPair;
    address private usdt;
    address private scar;
    address private miscAddress;
    address private treasuryAddress;
    address private operator; 

    constructor() {
        _disableInitializers();
    }

    function initialize(address _scar, address _usdt, address _miscAddress, address _treasuryAddress) initializer public {
        __Ownable_init();
        __UUPSUpgradeable_init();
        scar = _scar;
        usdt = _usdt;

        miscAddress = _miscAddress;
        treasuryAddress = _treasuryAddress;

        // uniRouter = IUniswapV2Router02(0x5dC5431D67cA080b7c4bf7CB77f1B3e6FeD0F1AC);
        // uniRouter = IUniswapV2Router02(0xC6A32f7c1796E699f97D89A75DDD2C0e8Ca8358A);   //RLC mainnet Router
        uniRouter = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E); // BSC Mainnet


        uniFactory = IUniswapV2Factory(uniRouter.factory());
        uniPair = uniFactory.getPair(scar, usdt);
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyOwner
        override
    {}

    function setOperator(address _operator) public onlyOwner{
        operator = _operator;
    }
    function getOperator() public view returns(address){
        return operator;
    }

    function getPairAddress() public view returns(address){
        return address(uniPair);
    }

    function setTreasueryWallet(address treasueryWallet_) external onlyOwner {
        treasuryAddress = treasueryWallet_;
    }

    function getTreasueryWallet()external view returns(address){
        return treasuryAddress;
    }

    function setMiscAddress(address treasueryWallet_) external onlyOwner {
        miscAddress = treasueryWallet_;
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

    // function liquidityHelper_() public {
    //     //require(msg.sender == operator, "Not authorized");
    //     uint256 tokenFee = IERC20(scar).balanceOf(address(this));
    //     uint256 adminShare = (tokenFee*20)/100;
    //     swapSCARToUSDT(adminShare);
    //     transferToAdmins();
    //     uint256 liquidityShare = tokenFee - adminShare;
    //     swapSCARToUSDT(liquidityShare/2);
    //     addliquidity();
    // }

    // function swapSCARToUSDT(uint256 tokenAmount) private {
    //      address[] memory path = new address[](2);
    //     path[0] = scar;
    //     path[1] = usdt;
    //     IERC20(scar).approve(address(uniRouter), tokenAmount);
    //     uniRouter.swapExactTokensForTokens(
    //         tokenAmount,
    //         0, // accept any amount of ETH
    //         path,
    //         address(this),
    //         block.timestamp
    //     );
    // }

    function addliquidity(uint256 scrAmount, uint256 usdtAmount)public onlyOwner {
        // uint256 scrAmount = IERC20(scar).balanceOf(address(this));
        // uint256 usdtAmount = IERC20(usdt).balanceOf(address(this));
        IERC20(scar).approve(address(uniPair), scrAmount);
        IERC20(scar).approve(address(uniPair), usdtAmount);
        
        IERC20(scar).approve(address(uniRouter), scrAmount);
        IERC20(usdt).approve(address(uniRouter), usdtAmount);
        uniRouter.addLiquidity(scar,usdt,scrAmount,usdtAmount,0,0,msg.sender,block.timestamp);
    }

    function removeLQ(uint256 liquidity) public onlyOwner{
        IERC20(uniPair).approve(address(uniRouter), liquidity);
        uniRouter.removeLiquidity(scar, usdt, liquidity, 0, 0, msg.sender, block.timestamp);
    }

//     function removeLiquidity(
//   address tokenA,
//   address tokenB,
//   uint liquidity,
//   uint amountAMin,
//   uint amountBMin,
//   address to,
//   uint deadline
// ) external returns (uint amountA, uint amountB);

    function transferToAdmins() private {
        uint256 usdtAmount = IERC20(usdt).balanceOf(address(this));
        IERC20(usdt).transfer(miscAddress, usdtAmount/2);
        IERC20(usdt).transfer(treasuryAddress, usdtAmount/2); 
    }


    function withdrawToken(address _tokenAddress, address destination, uint256 amount) public onlyOwner{
        IERC20(_tokenAddress).transfer(destination, amount);
    }

    function getTokenBalance(address _tokenAddress) public view returns(uint256) {
        return  IERC20(_tokenAddress).balanceOf(address(this));
    }

    function getCurrencyBalance() public view returns(uint256) {
        return address(this).balance;
    }

    function withdrawCurrency(address _destionation, uint256 _amount) public onlyOwner {

        payable(_destionation).transfer(_amount);
    }

    receive() external payable {
    }

    fallback() external payable {
    }

}