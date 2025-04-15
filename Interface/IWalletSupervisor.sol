// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

interface IWalletSupervisor{
    function increaseChainCount(address _user) external;
    function decreaseChainCount(address _user) external;
    // function getUserChainsCount(address _user) external view returns(uint32 chainCount);
    // function getMaxUsersCount() external view returns(uint256 maxUsersCount);
    // function getMaxChains() external view returns (uint32 maxChains);
    // function checkMaxWallet(address _user) external view returns(bool _maxWallet);
}
