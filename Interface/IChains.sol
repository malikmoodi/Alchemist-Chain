// SPDX-License-Identifier: MIT


pragma solidity 0.8.7;

// import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
interface IChains {
    
    function createChain(address to, string memory name) external returns(uint256);
    function calculateRewardsToken(uint256 tokenId) external view returns(uint256 rewards);
    function claimRewardsToken(uint256 tokenId, uint256 amount) external;
    function ownerOf(uint256 tokenId) external view returns (address);
    function getUserChains(address user) external view returns(uint256[] memory);
    function setChainManager(address _chainManager) external;
    function burn (uint256 tokenid, address owner) external;
    function getTotalClaimAmount(uint256 tokenId) external view returns (uint256 _claimedAmount);
    // function setUpkeepTime(uint256 _tokenId) external;
    // function calculateRewards(address owner) external returns(uint256 rewards);
    // function balanceOf(address owner) external returns(uint256 balance);
    // function calculateRewardsTokenWithTime(uint256 tokenId, uint256 since,uint256 till,bool isdue) external view returns(uint256 rewards);
    // function claimRewardsTokenWithTime(uint256 tokenId, uint256 since, uint256 till, bool isdue)external returns (uint256 rewards);
    // function updateLastClaimTime(uint256 _tokenId) external;
    // function calculateRewardsTime(uint256 tokenId, uint256 startTime, uint256 endTime) external view returns(uint256 rewards);
}