// SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

interface IBooster{
    // function buyBooster(address to) external returns(uint256 _tokenId);
    // function transferBooster(address from, address to, uint256 tokenId) external;
    function balanceOf(address owner) external view returns (uint256 balance);
    function getUserBoosters(address user) external view returns(uint256[] memory userboosts);
    
    function getUserBoosterDay(address _user)external view returns(uint256);
    function getBoosterPurchaseDay(address _user)external view returns(uint256);
    function getBoosterSellDay(address _user)external view returns(uint256);
    function getuserboostersDay(address user) external view returns(uint256);
    
    function setUserBoosterDay(address _user, uint256 _day) external;
    function setBoosterPurchaseDay(address _user, uint256 _day)external;
    function setBoosterSellDay(address _user, uint256 _day)external;

    function owner() external view returns(address);
}
