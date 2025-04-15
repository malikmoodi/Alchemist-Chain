// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface IPriceOracle {
    function getChangePercentage() external returns( uint256 percentage, bool direction);
}