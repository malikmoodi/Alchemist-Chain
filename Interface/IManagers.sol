// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface IManagers{
    function calculateRoi(uint256 tokenId) external view returns(uint256 roiPercent);
    function isUpKeepPaid(uint256 tokenid) external view returns(bool);
    function claimAllSilver(address user) external returns(uint256 _totalClaimedAmount);
    function createGCM(address _user, string memory name) external returns(uint256 _tokenId);
    function getSilverCreationFeeUsdt() external view returns(uint256 _silverCreationFeeUsdt);
    function getSilverChainCostUsdt() external view returns(uint256 _cost);
    // function payUpKeepFeeAllSilver(address user) external;
    // function createChainMigrator(string memory name, address user, uint256 numberOfChains) external;
    // function getPlatEligibility(address user) external view returns (uint256 timebelow, uint256 timeabove);
    // function resetupkeep(address user) external;
    // function getThreshholdTime(uint256 tokenId) external view returns(uint256 below, uint256 above);
    // function reserthreshholdtime (uint256 tokenId) external;
    // function setBelowTime(address user) external;
    // function setAboveTime(address user) external;
    // function bridgeMigrator(string memory name, address user, uint256 numberOfChains) external;
}