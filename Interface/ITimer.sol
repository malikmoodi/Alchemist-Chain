// SPDX-License-Identifier: MIT

pragma  solidity 0.8.7;

interface ITimer{
    function getDay() external view returns(uint256);
}