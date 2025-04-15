// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "./IUniswapV2Router02.sol";
import "./Ownable.sol";

contract UniOracle is Ownable{

    // IUniswapV2Router02 private router = IUniswapV2Router02(0x5dC5431D67cA080b7c4bf7CB77f1B3e6FeD0F1AC); //RLC TESTNET Router 
    // IUniswapV2Router02 router = IUniswapV2Router02(0xC6A32f7c1796E699f97D89A75DDD2C0e8Ca8358A);   //RLC mainnet Router
    IUniswapV2Router02 private router;
    // IUniswapV2Router02 private router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D); //Ether

    uint256 private baseprice;

    address public token0;
    address public token1;


    constructor(address _alcc, address _usdt) {
        baseprice = 10*10**18;
        token0 = _alcc;
        token1 = _usdt;
        router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E); // BSC Mainnet

    }

    function setBasePrice(uint256 _price) public onlyOwner{
        baseprice = _price;
    }

    function getBasePrice() public view returns(uint256){
        return baseprice;
    }
    
    function getAmount() public view returns(uint256 amount0, uint256 amount1){
        address[] memory path;
        uint256[] memory amounts;

        path = new address[](2);
        path[0] = token0;
        path[1] = token1;

        amounts = router.getAmountsOut(1000000000000000000, path);
        amount0 = amounts[0];
        amount1 = amounts[1];

        return(amount0, amount1);
    }

    function getChangePercentage() public view returns(uint256, bool){
        uint256 percentage;
        bool direction;
        (,uint256 price)=getAmount();

        if(baseprice<= price){
            uint256 up =  price - baseprice;
            percentage = ((up *100)/baseprice);
            direction = true;
            return (percentage, direction);
        }
        else{
            uint256 up = baseprice - price;      
            percentage = ((up *100)/baseprice);

            direction = false;

            return (percentage, direction);
        }
    }

    
}
