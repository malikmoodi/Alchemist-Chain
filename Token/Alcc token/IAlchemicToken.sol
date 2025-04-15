// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface IAlchemicToken {
    // function getChangePercentage() external returns( uint256 percentage, bool direction);
    function distributeReward(uint256 amount) external;
    function burn(uint256 amount) external returns (bool);

}