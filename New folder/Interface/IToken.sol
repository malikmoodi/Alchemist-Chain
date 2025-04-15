// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;
import "./IERC20.sol";  

interface IToken is IERC20{
    function distributeReward(uint256) external;
}