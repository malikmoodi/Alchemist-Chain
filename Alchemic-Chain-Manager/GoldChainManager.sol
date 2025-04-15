// SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

import "../Interface/IChains.sol";
// import "../Interface/IERC20.sol";
import "../Interface/IBooster.sol";
import "../HelperContracts/SafeMath.sol";
import "../Interface/IManagers.sol";
import "../Interface/IToken.sol";
import "../Interface/ITimer.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract GoldChainManager is Initializable, OwnableUpgradeable, UUPSUpgradeable{
    using SafeMath for uint256;

    event chainCreated(address to, string name, uint256 tokenId);
    // event paymentRecieved(address sender, uint256 amount);
    // event fallbackCalled(address sender, uint256 amount);

    mapping (uint256 => uint256) private daysOverDue; 
    mapping (uint256 => uint256) private tokenLastUpkeepTime; 
    mapping (uint256 => uint256) public tokenLastActionDay;
    mapping (address => uint256) private userLastActionDay;
    // mapping (uint256 => uint256) private tokenLastClaimTime;

    address private settingContract;
    address private alccToken;
    address private usdt;
    address private silverChainAddress;
    address private silverChainManager;
    address private goldChainAddress;
    address private ouroBooster;
    address private timerContract;
    address private borosBooster;

    // uint256 private rewardPeriod;
    uint256 private alxToUsdtRate;
    uint256 private goldCreationFeeToken;  
    uint256 private goldCreationFeeUsdt;  
    uint256 private goldRewardsPerPeriod;

    uint256 private goldClaimTax;
    uint256 private compoundTax;
    uint256 private upkeepPercentage;
    
    uint256 private ouroRewardBenefit;
    uint256 private ouroUpkeepReduction;
    // uint256 private ouroPrice;

    uint256 private borosRewardBenefit;
    uint256 private borosUpkeepReduction;
    // uint256 private borosPrice;

    uint256 private ouroborosRewardBenefit;
    uint256 private ouroborosUpkeepReduction;
    
    uint256 private startTime; 
    uint256 private requiredSilverChains; 
    uint256 private upKeepCycleGold;
    uint256 private roiLimit;

    string constant TOKEN_NOT_APPROVED = "GCM1";
    string constant TOTAL_TOKEN_NOT_APPROVED = "GCM2";
    string constant ONE_ACTION_PER_DAY_ALLOWED = "GCM3";
    string constant UPKEEP_NOT_PAID = "GCM4";
    string constant USER_IS_NOT_OWNER = "GCM5";
    string constant NOT_ENOUGH_TOKENS = "GCM6";
    string constant NOT_ENOUGH_CHAINS = "GCM7";
    string constant SILVER_CHAIN_UPKEEP_UNPAID = "GCM8";
    string constant NOT_AUTHORIZED = "GCM9";
    string constant USER_ONLY_ONE_ACTION_IN_DAY = "GCM10";
    string constant TOKEN_ONLY_ONE_ACTION_IN_DAY = "GCM11";
    string constant LESS_AMOUNT_TO_COMPOUND = "GCM12";
    string constant NO_TOKENS = "GCM13";
    string constant NO_CURRENCY = "GCM14";
    string constant UPKEEP_IS_0 = "GCM15";

    uint256 private silverCreationFeeToken;  
    uint256 private usdtLqLimit;
    address private liquidityHelper;
    
    string constant USER_CHAIN_REACH_ROI = "GCM16";

    /**
        * @dev Initialize: Deploy Alchemic Gold Chain Manager and set the basic values 
        @param _alccToken Contract address of Alx token
        @param _usdt Contract address of USDT token
        @param _silverChainManager Contract address of Alchemic Silver Chain Manager
        @param _silverChainAddress Contract address of Alchemic Silver Chain
        @param _goldChainAddress Contract address of Alchemic Gold Chain
        @param _ouro Booster Contract address
        @param _boros Booster Contract address
        @param _settingContract Setting Contract address
        *
    */
    function initialize(address _alccToken, address _usdt, address _silverChainManager, address _silverChainAddress, 
                    address _goldChainAddress, address _ouro, address _boros, address _settingContract, address _liquidityHelper, address _timer) initializer public {
        __Ownable_init();
        __UUPSUpgradeable_init();

        silverChainAddress = _silverChainAddress;
        goldChainAddress = _goldChainAddress;
        silverChainManager = _silverChainManager;
        alccToken = _alccToken;
        usdt = _usdt;
        ouroBooster = _ouro;
        borosBooster = _boros;
        timerContract = _timer;
        settingContract = _settingContract;
        liquidityHelper = _liquidityHelper;

        upKeepCycleGold = 7; //7Days
        // startTime = block.timestamp; 
        // rewardPeriod = 5 minutes;  // 1Day
        alxToUsdtRate = 10;
        roiLimit= 200;
        goldCreationFeeToken = 12*(10**18);
        goldCreationFeeUsdt = 20*(10**18);
        requiredSilverChains = 2; 

        goldRewardsPerPeriod = 1*(10**18); // 1 per day
        goldClaimTax = 15;
        compoundTax = 5;
         
        upkeepPercentage = 10; /// upkeep will be 10% of all rewards, in usdt

        ouroborosRewardBenefit = 10;
        ouroborosUpkeepReduction = 5;

        ouroRewardBenefit = 5;
        ouroUpkeepReduction = 2;
        // ouroPrice = 800*(10**18);

        borosRewardBenefit = 2;
        borosUpkeepReduction = 1;
        // borosPrice = 400*(10**18);
        silverCreationFeeToken = 10*10**18;
        usdtLqLimit = 10*10**18;

    }

    function _authorizeUpgrade(address newImplementation) internal onlyOwner override{}

    function createGoldChainPri(string memory name) private{
        require(!userChainReachROI(msg.sender), USER_CHAIN_REACH_ROI);
        uint256 tokenId = IChains(goldChainAddress).createChain(msg.sender, name);
        emit chainCreated(msg.sender, name, tokenId);

        tokenLastUpkeepTime[tokenId] = ITimer(timerContract).getDay();  
    }

    /**
        * @dev createGoldChain: To create Gold chain this method transfer required token amount from user to this contract and burn Required silver chains. 
        At time of creation it emits an event chainCreated with User's address, name of chain and token Id of chain.
        @param name Name of chain
        @param chains Silver chain token ids array  
    */
    function createGoldChain(uint256[] memory chains, string memory name) public {
        require (IToken(alccToken).allowance(msg.sender, address(this)) >= goldCreationFeeToken, TOKEN_NOT_APPROVED);
        require (IToken(usdt).allowance(msg.sender, address(this)) >= goldCreationFeeUsdt, TOKEN_NOT_APPROVED);
        require (isEligible(msg.sender), NOT_ENOUGH_CHAINS); 
        IToken(alccToken).transferFrom(msg.sender, address(this), goldCreationFeeToken);
        IToken(usdt).transferFrom(msg.sender, address(this), goldCreationFeeUsdt);

        for(uint i = 0 ; i < requiredSilverChains ; i++){
            if(!IManagers(silverChainManager).isUpKeepPaid(chains[i])){
                revert(SILVER_CHAIN_UPKEEP_UNPAID);
            }
            IChains(silverChainAddress).burn(chains[i], msg.sender);
        }

        createGoldChainPri(name);
        transferToLiquidityHelper();
    }

    /**
        * @dev createMultipleGoldChain: To create multiple Gold chain this method transfer required tokens amount from user to this contract and burn Required silver chains. 
        At time of creation it emits an event chainCreated with User's address, name of chain and token Id of chain.
        @param name Name of chain
        @param chains Silver chain token ids array  
        @param numberOfGoldChains Number of chains to create  
    */
    function createMultipleGoldChain(uint256[] memory chains, string memory name, uint256 numberOfGoldChains) public {
        uint256 totalTokenFee = goldCreationFeeToken.mul(numberOfGoldChains);
        uint256 totalUsdtFee = goldCreationFeeUsdt.mul(numberOfGoldChains);
        uint256 silverChains = requiredSilverChains.mul(numberOfGoldChains);
        require (IChains(silverChainAddress).getUserChains(msg.sender).length >= silverChains, NOT_ENOUGH_CHAINS); 
        require (IToken(alccToken).allowance(msg.sender, address(this)) >= totalTokenFee, TOTAL_TOKEN_NOT_APPROVED);
        require (IToken(usdt).allowance(msg.sender, address(this)) >= totalUsdtFee, TOTAL_TOKEN_NOT_APPROVED);
        IToken(alccToken).transferFrom(msg.sender, address(this), totalTokenFee);
        IToken(usdt).transferFrom(msg.sender, address(this), totalUsdtFee);

        for(uint i = 0 ; i < silverChains; i++){
            if(!IManagers(silverChainManager).isUpKeepPaid(chains[i])){
                revert(SILVER_CHAIN_UPKEEP_UNPAID);
            }
            IChains(silverChainAddress).burn(chains[i], msg.sender);
        }

        for(uint256 i = 0 ; i < numberOfGoldChains; i ++){
            createGoldChainPri(name);
        }
        transferToLiquidityHelper();
    }

    function getCompoundTaxValue(address _user) public view returns(uint256 taxInUsdt){
        (uint256 rewardToMint, )= calculateAllGoldReward(_user);
        uint256 usdtAmount = ((rewardToMint.mul(compoundTax)).div(100)).mul(alxToUsdtRate);
        return usdtAmount;
    }

    /**
        * @dev compoundSilverChain: To compound silver chain, this method claim user's chains reward, add booster enhancement in reward amount if user have booster, without claim tax deduction.
        Will update claim amount of silver chains.

        @param name Name of chain 
        @param numberOfCompounds Number of chains to create 
        @param tokenAmount Remaining Token amount to compound chain
    */
    function compoundSilverChain(string memory name, uint256 numberOfCompounds, uint256 tokenAmount) public{
        require(userLastActionDay[msg.sender] != ITimer(timerContract).getDay(), USER_ONLY_ONE_ACTION_IN_DAY);
        require(!userChainReachROI(msg.sender), USER_CHAIN_REACH_ROI);
        uint256[] memory chains = IChains(goldChainAddress).getUserChains(msg.sender);
        
        // uint256 rewardDiff;
        (uint256 rewardToMint, ) = calculateAllGoldReward(msg.sender);
        uint256 usdtAmount = getCompoundTaxValue(msg.sender);
        IToken(usdt).transferFrom(msg.sender,address(this), 
            (IManagers(silverChainManager).getSilverCreationFeeUsdt().mul(numberOfCompounds)).add(usdtAmount));


        uint256 totalAmount;
        uint256 amountDiff;
        uint256 claimedAmount;

        IToken(alccToken).distributeReward(rewardToMint);       

        if(rewardToMint > silverCreationFeeToken.mul(numberOfCompounds)){
            amountDiff = rewardToMint.sub(silverCreationFeeToken.mul(numberOfCompounds));
            // amountDiff = amountDiff.sub((amountDiff.mul(goldClaimTax)).div(100));
            claimedAmount = amountDiff.div(chains.length);

        }else if(rewardToMint < silverCreationFeeToken.mul(numberOfCompounds)){
            totalAmount = (rewardToMint.add(tokenAmount));
            require(totalAmount >= silverCreationFeeToken.mul(numberOfCompounds), LESS_AMOUNT_TO_COMPOUND);
            IToken(alccToken).transferFrom(msg.sender, address(this), tokenAmount);
            
            amountDiff = totalAmount.sub(silverCreationFeeToken.mul(numberOfCompounds));
        }

        uint256 totalClaimed;
        uint256 transferClaim;

        for (uint i = 0 ; i < chains.length; i++){
            if(claimedAmount > 0){
                uint256 a = calculateAdvancedRoi(claimedAmount, chains[i]); 
                uint256 b = goldClaimTax;

                if(a > 99 && a < roiLimit ){
                    b = 55;
                    transferClaim = claimedAmount.sub((b).mul(claimedAmount.div(100))); 
                }else if(a >= roiLimit ){
                    transferClaim = 0;
                }else{
                    transferClaim = claimedAmount.sub((b).mul(claimedAmount.div(100))); 
                }
                totalClaimed += transferClaim;
            }

            IChains(goldChainAddress).claimRewardsToken(chains[i], transferClaim);
            
            daysOverDue[chains[i]] = 0;
            tokenLastActionDay[chains[i]] = ITimer(timerContract).getDay();
        }

        amountDiff = totalClaimed;
        
        if(amountDiff > 0){
            IToken(alccToken).transfer(msg.sender, amountDiff);
        }

        for(uint256 i = 0 ; i < numberOfCompounds; i ++){
            uint256 tokenId = IManagers(silverChainManager).createGCM(msg.sender,  name);
            emit chainCreated(msg.sender, name, tokenId);
        }
        transferToLiquidityHelper();
    }

    function getUserBoosterPercentage(address _user) public view returns(uint256 _percentage){
        bool ouroBoosterStatus = getOuroBoosters(_user).length > 0;
        bool borosBoosterStatus = getBorosBoosters(_user).length > 0;
        // uint256 ouroDay = IBooster(ouroBooster).getUserBoosterDay(_user);
        // uint256 borosDay = IBooster(borosBooster).getUserBoosterDay(_user);
        
        if((!borosBoosterStatus ) && ouroBoosterStatus ){
            return ouroRewardBenefit; 
        }else if((!ouroBoosterStatus)  && borosBoosterStatus ){
            return borosRewardBenefit; 
        }else if(ouroBoosterStatus && borosBoosterStatus){
            return ouroborosRewardBenefit; 
        }
    }

    function getRewardsToTransfer(uint256 rewardToMint, address _user) private view returns(uint256 _rewardToMint){
        bool ouroBoosterStatus = getOuroBoosters(_user).length > 0;
        bool borosBoosterStatus = getBorosBoosters(_user).length > 0;
        uint256 ouroDay = IBooster(ouroBooster).getUserBoosterDay(_user);
        uint256 borosDay = IBooster(borosBooster).getUserBoosterDay(_user);
        
        if((!borosBoosterStatus || ITimer(timerContract).getDay() == borosDay) && ouroBoosterStatus && ITimer(timerContract).getDay() > ouroDay){
            rewardToMint = rewardToMint.add((ouroRewardBenefit).mul(rewardToMint.div(100))); 
        }else if((!ouroBoosterStatus || ITimer(timerContract).getDay() == ouroDay)  && borosBoosterStatus && ITimer(timerContract).getDay() > borosDay){
            rewardToMint = rewardToMint.add((borosRewardBenefit).mul(rewardToMint.div(100))); 
        }else if(ouroBoosterStatus && borosBoosterStatus){
            rewardToMint = rewardToMint.add((ouroborosRewardBenefit).mul(rewardToMint.div(100))); 
        }

        return rewardToMint;
    }

    function calculateAdvancedRoi(uint256 _rewardToMint, uint256 tokenId) private view returns(uint256 roiPercent){
        _rewardToMint = _rewardToMint.sub((_rewardToMint.mul(goldClaimTax)).div(100));
        uint256 claimedAmount = IChains(goldChainAddress).getTotalClaimAmount(tokenId);
        uint256 total = _rewardToMint.add(claimedAmount);
        total = total.sub((total.mul(goldClaimTax)).div(100));
        roiPercent = ((total.mul(alxToUsdtRate)).mul(100)).div(getGoldChainCostUsdt());
        return roiPercent;
    }

    /**
        @dev calculateRewardsGold: Calculates reward of specific gold chain.
        @param tokenId Token id of chain
        @param rewardToMint Calculated reward of chain to Mint
        @param rewardToTransfer Final amount to transfer
    */
    function calculateRewardsGold(uint256 tokenId)public view returns(uint256 rewardToMint, uint256 rewardToTransfer){
        rewardToMint = IChains(goldChainAddress).calculateRewardsToken(tokenId);
        address user = IChains(goldChainAddress).ownerOf(tokenId);

        uint256 totalDays = daysOverDue[tokenId]; 

        if(ITimer(timerContract).getDay() > tokenLastUpkeepTime[tokenId].add(upKeepCycleGold)){
            uint256 time = (ITimer(timerContract).getDay().sub(tokenLastUpkeepTime[tokenId].add(upKeepCycleGold)));
            // .div(rewardPeriod); 
            totalDays  += time;  
        }

        if(totalDays.mul(goldRewardsPerPeriod) > rewardToMint){
            return (0, 0);
        }

        // if(calculateRoi(tokenId) > 199){
        if(calculateRoi(tokenId) > 149){
            return (0,0);
        }
        rewardToMint = rewardToMint.sub(totalDays.mul(goldRewardsPerPeriod));
        rewardToMint = getRewardsToTransfer(rewardToMint, user);
        uint256 a = calculateAdvancedRoi(rewardToMint, tokenId); 
        uint256 b = goldClaimTax;

        if(a > 99){
            b = 55;
        }

        rewardToTransfer = rewardToMint.sub((b).mul(rewardToMint.div(100))); 

        uint256 claimedAmount = IChains(goldChainAddress).getTotalClaimAmount(tokenId);
        claimedAmount = claimedAmount.sub((claimedAmount.mul(goldClaimTax)).div(100));

        uint256 total = claimedAmount.add(rewardToTransfer);
        uint256 maxRoiPrice = ((getGoldChainCostUsdt().mul(getRoiLimit())).div(100)).div(alxToUsdtRate);

        if(total > maxRoiPrice){
            if(maxRoiPrice > claimedAmount){
                rewardToTransfer = maxRoiPrice.sub(claimedAmount);
            }else{
                rewardToTransfer = 0;
            }
        }
        return (rewardToMint, rewardToTransfer);               
    }

    /**
        @dev Calculates ROI of specific token id.
        @param tokenId Token id of chain
        @param roiPercent ROI Percentage
    */
    function calculateRoi(uint256 tokenId) public view returns(uint256 roiPercent){
        uint256 claimedAmount = IChains(goldChainAddress).getTotalClaimAmount(tokenId);
        claimedAmount = claimedAmount.sub((claimedAmount.mul(goldClaimTax)).div(100));
        uint256 maxRoiPrice = ((getGoldChainCostUsdt().mul(getRoiLimit())).div(100)).div(alxToUsdtRate);

        roiPercent = (claimedAmount.mul(alxToUsdtRate).mul(100)).div(getGoldChainCostUsdt());

        if(claimedAmount > maxRoiPrice.sub(5*10**17)){
            roiPercent = (((claimedAmount.mul(alxToUsdtRate)).mul(100)).div(getGoldChainCostUsdt())).add(1);
        }else{
            roiPercent = ((claimedAmount.mul(alxToUsdtRate)).mul(100)).div(getGoldChainCostUsdt());
        }
    }

    /**
        @dev calculateAllGoldReward: Calculates reward of all gold chains of user.
        @param user Chains owner address
        @param _rewardToMint Calculated all reward of chains to mint
        @param _rewardToTransfer Calculated all reward of chains to transfer
    */
    function calculateAllGoldReward(address user) public view returns(uint256 _rewardToMint, uint256 _rewardToTransfer) {
        uint256[] memory chains = IChains(goldChainAddress).getUserChains(user);
        uint256 rewardToMint;
        uint256 rewardToTransfer;
        for (uint i = 0 ; i < chains.length; i++){
            (rewardToMint, rewardToTransfer)= calculateRewardsGold(chains[i]);  
            _rewardToMint += rewardToMint;
           _rewardToTransfer += rewardToTransfer;
        }
        return (_rewardToMint, _rewardToTransfer);
    }
    
    /**
        @dev claimRewardsGold: Claim amount of chain and transfer alx token to owner of chain.
        @param tokenId Token id of chain
        @param _claimedAmount Claimed amount of chain

    */
    function claimRewardsGold(uint256 tokenId) public returns (uint256 _claimedAmount){
        require(tokenLastActionDay[tokenId] != ITimer(timerContract).getDay(), TOKEN_ONLY_ONE_ACTION_IN_DAY);
        require(userLastActionDay[msg.sender] != ITimer(timerContract).getDay(), USER_ONLY_ONE_ACTION_IN_DAY);
        _claimedAmount = claimReward(tokenId);
        transferToLiquidityHelper();
        return _claimedAmount;
    }

    function claimReward(uint256 tokenId) private returns (uint256 _claimedAmount){
        require(isUpKeepPaid(tokenId), UPKEEP_NOT_PAID);  
        require(IChains(goldChainAddress).ownerOf(tokenId) == msg.sender, USER_IS_NOT_OWNER);
        (uint256 rewardToMint, uint256 rewardToTransfer) = calculateRewardsGold(tokenId);
        if(rewardToMint > 0){
            IToken(alccToken).distributeReward(rewardToMint);
            IChains(goldChainAddress).claimRewardsToken(tokenId, rewardToTransfer);
            
            IToken(alccToken).transfer(msg.sender, rewardToTransfer);
            
            daysOverDue[tokenId] = 0;
            tokenLastActionDay[tokenId] = ITimer(timerContract).getDay();
        }
        return rewardToTransfer;
    }

    /**
        @dev claimAllGold: Claims reward of all gold chain of user, and transfer alx token to owner of chains.
        @param _totalClaimedAmount Total claimed amount of chains

    */
    function claimAllGold(address user) public returns(uint256 _totalClaimedAmount) {
        require(userLastActionDay[user] != ITimer(timerContract).getDay(), USER_ONLY_ONE_ACTION_IN_DAY);
        uint256[] memory chains = IChains(goldChainAddress).getUserChains(user);
        uint256 totalClaimedAmount = 0;
        for (uint i = 0 ; i < chains.length; i++){
            if(calculateRoi(chains[i]) < getRoiLimit()){
                if(tokenLastActionDay[chains[i]] != ITimer(timerContract).getDay()){
                    totalClaimedAmount += claimRewardsGold(chains[i]);
                }   
            }
        }
        userLastActionDay[user]= ITimer(timerContract).getDay();
        transferToLiquidityHelper();
        return totalClaimedAmount;
    }

    /**
        @dev User pay upkeep of specific gold chain. And amount of upkeep transfer from user to contract
        @param tokenId Token id of chain

    */
    function payUpKeepFeeGold(uint256 tokenId) public {
        payUpkeepPVT(tokenId);
        transferToLiquidityHelper();
    }

    function payUpkeepPVT(uint256 tokenId)private{
        uint256 fee = getTokenUpKeepFeeGold(tokenId);
        if(fee > 0){
            IToken(usdt).transferFrom(msg.sender,address(this),fee);
            if(ITimer(timerContract).getDay() > tokenLastUpkeepTime[tokenId].add(upKeepCycleGold)){
                uint256 Days = (ITimer(timerContract).getDay() - (tokenLastUpkeepTime[tokenId].add(upKeepCycleGold)));
                // .div(rewardPeriod);
                daysOverDue[tokenId] += Days;
            }
            tokenLastUpkeepTime[tokenId]= ITimer(timerContract).getDay();
        }
    }
    /**
       @dev User pay upkeep of all gold chains. And amount of total upkeep transfer from user to contract

    */
    function payUpKeepFeeAllGold(address user) public {
        uint256[] memory tokenId = IChains(goldChainAddress).getUserChains(user);
        for(uint256 i; i < tokenId.length; i++){
            if(calculateRoi(tokenId[i]) < getRoiLimit()){
                payUpkeepPVT(tokenId[i]);
            }
        }
        transferToLiquidityHelper();
    }
    
    /**
        @dev Returns upkeep amount of all gold chains of user.
        @param _upkeepFeeAll Total Upkeep amount of all gold chains
    */
    function getUpKeepFeeAllGold(address user) public view returns(uint256 _upkeepFeeAll){
        uint256 upkeepFeeAll;
        uint256[] memory tokenId = IChains(goldChainAddress).getUserChains(user);

        for(uint256 i; i < tokenId.length; i++){
            upkeepFeeAll += getTokenUpKeepFeeGold(tokenId[i]);
        }      

        return upkeepFeeAll;
    }
    
    /**
        @dev Returns upkeep amount of specfic gold chain of user.
        @param upkeepFee Upkeep fee amount of gold chain
        @param tokenId Token id of chain

    */
    function getTokenUpKeepFeeGold(uint256 tokenId) public view returns(uint256 upkeepFee){
        uint256 rewards;
        address user = IChains(goldChainAddress).ownerOf(tokenId);


        if(calculateRoi(tokenId) > roiLimit){
            return (0);
        }
        
        if(isUpKeepPaid(tokenId)){
            uint256 timeSinceUpkeep = (ITimer(timerContract).getDay().sub(tokenLastUpkeepTime[tokenId]));
            // .div(rewardPeriod);
            rewards = goldRewardsPerPeriod.mul(timeSinceUpkeep);
        }else {
            rewards = goldRewardsPerPeriod.mul(upKeepCycleGold/*.div(rewardPeriod)*/);
        }

        upkeepFee = getUpkeepFeePVT(rewards, user);

        return upkeepFee.mul(alxToUsdtRate); //// usdt price to alx
    }

    function getUpkeepFeePVT(uint256 rewards, address _user) private view returns(uint256 upkeepFee){
        bool ouroBoosterStatus = getOuroBoosters(_user).length > 0;
        bool borosBoosterStatus = getBorosBoosters(_user).length > 0;
        uint256 ouroDay = IBooster(ouroBooster).getUserBoosterDay(_user);
        uint256 borosDay = IBooster(borosBooster).getUserBoosterDay(_user);
        
        if((!borosBoosterStatus || ITimer(timerContract).getDay() == borosDay) && ouroBoosterStatus && ITimer(timerContract).getDay() > ouroDay){
            upkeepFee = (((upkeepPercentage.sub(ouroUpkeepReduction)).mul(rewards.add((ouroRewardBenefit).mul(rewards.div(100))))).div(100));
        }else if((!ouroBoosterStatus || ITimer(timerContract).getDay() == ouroDay)  && borosBoosterStatus && ITimer(timerContract).getDay() > borosDay){
            upkeepFee = (((upkeepPercentage.sub(borosUpkeepReduction)).mul(rewards.add((borosRewardBenefit).mul(rewards.div(100))))).div(100));
        }else if(ouroBoosterStatus && borosBoosterStatus){
            upkeepFee = ((upkeepPercentage.sub(ouroborosUpkeepReduction)).mul(rewards.add((ouroborosRewardBenefit).mul(rewards.div(100))))).div(100);
        }else{
            upkeepFee = (upkeepPercentage.mul(rewards)).div(100);
        }

        return upkeepFee;
    }

    function getBoosterPercentage(uint256 _percentage, uint256 _reward) private pure returns(uint256 _value){
        return _value = (_percentage).mul(_reward.div(100));
    } 


    /**
        @dev Returns upkeep amount of specfic silver chain is paid or unpaid.
        @param tokenId Token id of chain
        @param upkeepStatus Upkeep paid or unpaid

    */
    function isUpKeepPaid(uint256 tokenId) public view returns(bool upkeepStatus){
        uint256 feeTime = tokenLastUpkeepTime[tokenId];
        if(calculateRoi(tokenId) >= roiLimit){
            return true;
        }else{
            return (feeTime.add(upKeepCycleGold)) >= ITimer(timerContract).getDay(); 
        }
    }

    /**
        @dev Returns Eligibility of user to create gold chain.
        @param user User address
        @param _requiredSilverChainStatus Upkeep paid or unpaid

    */
    function isEligible(address user) public view returns(bool _requiredSilverChainStatus){
        uint256[] memory silverChains = IChains(silverChainAddress).getUserChains(user);
        if(silverChains.length >= requiredSilverChains){
            return true;
        }
        return false;
    }
    
    // // function transferBorosBooster(address to, uint256 boosterId) public {
    // //     IManagers(silverChainManager).payUpKeepFeeAllSilver(msg.sender);
    // //     IManagers(silverChainManager).claimAllSilver(msg.sender);
    // //     payUpKeepFeeAllGold(msg.sender);
    // //     claimAllGold(msg.sender);

    // //     IBooster(borosBooster).transferBooster(msg.sender, to, boosterId);
    // // }

    // /**
    //     @dev User can transfer booster to anyother user. Before transfer of booster, this method will pay all due upkeep amount of new owner and 
    //     claim all amount of new owner's chains   
    //     @param to User address
    //     @param boosterId Transfered Booster id

    // */    
    // // function transferOuroBooster(address to, uint256 boosterId) public {
    // //     IManagers(silverChainManager).payUpKeepFeeAllSilver(msg.sender);
    // //     IManagers(silverChainManager).claimAllSilver(msg.sender);
    // //     payUpKeepFeeAllGold(msg.sender);
    // //     claimAllGold(msg.sender);

    // //     IBooster(ouroBooster).transferBooster(msg.sender, to, boosterId);
    // // }
    function transferToLiquidityHelper()private{
        uint256 usdtBalance = IERC20(usdt).balanceOf(address(this));
        uint256 alccBalance = IERC20(alccToken).balanceOf(address(this));
        if(usdtBalance >= usdtLqLimit){
            IERC20(usdt).transfer(liquidityHelper, usdtBalance);
            if(alccBalance > 0){
                IERC20(alccToken).transfer(liquidityHelper, alccBalance);
            }
        }
    }

////////////// Setters & Getters ////////////
    function userChainReachROI(address _user)public view returns(bool _status){
        uint256[] memory chains = IChains(goldChainAddress).getUserChains(_user);
        for(uint i; i < chains.length; i++){
            if(calculateRoi(chains[i]) > roiLimit){
                return true;
            }
        }
        return false;
    }

    function setLiquidityHelper(address _liquidityHelper) public {
        require(settingContract == msg.sender, NOT_AUTHORIZED);
        liquidityHelper = _liquidityHelper;
    }

    function getLiquidityHelper() public view returns(address _liquidityHelper){
        return liquidityHelper;
    }

    function getUsdtLqLimit() public view returns(uint256 _usdtLqLimit) {
        return usdtLqLimit;
    }

    function setUsdtLqLimit(uint256 _usdtLqLimit) public{
        require(settingContract == msg.sender, NOT_AUTHORIZED);
        usdtLqLimit = _usdtLqLimit;
    }
    function getGoldChainCostUsdt() public view returns(uint256 _cost){
        // 
        uint256 cost = goldCreationFeeUsdt.add(IManagers(silverChainManager).getSilverChainCostUsdt().mul(requiredSilverChains)).add(goldCreationFeeToken.mul(alxToUsdtRate));
        return cost;
    }
    
    /**
    * @dev Returns Timer contract address.     
    @param _timerContract Silver chain manager contract address
    */ 
    // function getTimerContract() public view returns (address _timerContract) {
    //     return timerContract;
    // }

    /**
    * @dev Sets Timer contract address. Only Setting contract can call this method.     
    @param _timerContract Silver chain manager address
    */ 
    function setTimerContract(address _timerContract) public {
        require(settingContract == msg.sender, NOT_AUTHORIZED);
        timerContract = _timerContract;
    }
    /**
    * @dev Returns silver creation fee in usdt.
    @param _goldCreationFeeUsdt Creation fee in usdt 
    */  
    function getGoldCreationFeeUsdt() public view returns(uint256 _goldCreationFeeUsdt) {
        return goldCreationFeeUsdt;
    }

    /**
    * @dev Sets silver creation fee in usdt. Only setting contract can set this value   
    @param _goldCreationFeeUsdt Creation fee in usdt 
    */ 
    function setGoldCreationFeeUsdt(uint256 _goldCreationFeeUsdt) public{
        require(settingContract == msg.sender, NOT_AUTHORIZED);
        goldCreationFeeUsdt = _goldCreationFeeUsdt;
    }

    /**
    * @dev Returns silver upkeep cycle.
    @param _upkeepPercentage Upkeep cycle in days 
    */  
    function getUpkeepPercentage() public view returns(uint256 _upkeepPercentage) {
        return upkeepPercentage;
    }

    /**
    * @dev Sets silver upkeep cycle. Only setting contract can set this value   
    @param _upkeepPercentage Upkeep cycle in days 
    */ 
    function setUpkeepPercentage(uint256 _upkeepPercentage) public{
        require(settingContract == msg.sender, NOT_AUTHORIZED);
        upkeepPercentage = _upkeepPercentage;
    }
    /**
    * @dev Returns Last action day of user.     
    @param tokenId token Id of chain
    @param _lastUpkeepTime Last upkeep time
    */
    function getTokenLastUpkeepTime(uint256 tokenId) public view returns(uint256 _lastUpkeepTime){
        return tokenLastUpkeepTime[tokenId];
    }

    /**
    * @dev Returns Last action day of user.     
    @param tokenId token Id of chain
    @param _lastDay Last action day
    */
    function getTokenLastActionDay(uint256 tokenId) public view returns(uint256 _lastDay){
        return tokenLastActionDay[tokenId];
    }

    /**
    * @dev Returns Last action day of user.     
    @param user User address
    @param _lastDay Last action day
    */
    function getUserLastActionDay(address user) public view returns(uint256 _lastDay){
        return userLastActionDay[user];
    }

    /**
    * @dev Returns gold upkeep cycle.
    @param _requiredSilverChain Upkeep cycle in days
    */  
    function getRequiredSilverChains() public view returns(uint256 _requiredSilverChain) {
        return requiredSilverChains;
    }

    /**
    * @dev Sets gold upkeep cycle. Only setting contract can set this value   
    @param _requiredSilverChain Upkeep cycle in days
    */ 
    function setRequiredSilverChains(uint256 _requiredSilverChain) public{
        require(settingContract == msg.sender, NOT_AUTHORIZED);
        requiredSilverChains = _requiredSilverChain;
    }


    /**
    * @dev Returns gold upkeep cycle.
    @param _upKeepCycleGold Upkeep cycle in days
    */  
    function getGoldUpkeepCycle() public view returns(uint256 _upKeepCycleGold) {
        return upKeepCycleGold;
    }

    /**
    * @dev Sets gold upkeep cycle. Only setting contract can set this value   
    @param _upKeepCycleGold Upkeep cycle in days
    */ 
    function setGoldUpkeepCycle(uint256 _upKeepCycleGold) public{
        require(settingContract == msg.sender, NOT_AUTHORIZED);
        // upKeepCycleGold = _upKeepCycleGold.mul(rewardPeriod);
        upKeepCycleGold = _upKeepCycleGold;
    }

    /**
    * @dev Returns Booster Ids of user     
    @param user User address
    @param userBoosts Booster Id array
    */   
    function getOuroBoosters(address user) public view returns(uint256[] memory userBoosts){
        return (IBooster(ouroBooster).getUserBoosters(user));
    }
    
    /**
    * @dev Returns Booster Ids of user     
    @param user User address
    @param userBoosts Booster Id array
    */   
    function getBorosBoosters(address user) public view returns(uint256[] memory userBoosts){
        return (IBooster(borosBooster).getUserBoosters(user));
    }

    /**
    * @dev Returns upkeep detail of specific chain. if upkeep not due then returns "0", and upkeep due then returns time.      
    @param tokenId token Id of chain
    @param time Returns upkeep time of chain 
    */ 
    function getUpKeepDetails(uint256 tokenId) public view returns(uint256 time){
        if(ITimer(timerContract).getDay() < (tokenLastUpkeepTime[tokenId].add(upKeepCycleGold))){
            return (tokenLastUpkeepTime[tokenId].add(upKeepCycleGold)).sub(ITimer(timerContract).getDay());
        }
        return 0;
    }

    /**
    * @dev Returns over due days of specific chain.
    @param tokenId token Id of chain
    @param _days Returns overdue days of chain 
    */ 
    function getOverdueDays(uint256 tokenId) public view returns(uint256 _days){
        return daysOverDue[tokenId];
    }

    // /**
    // * @dev Returns days from deployed silver chain manager to today.
    // @param _days Returns overdue days of chain 
    // */ 
    // function getDay() public view returns(uint256 _days){
    //     return (block.timestamp.sub(startTime)).div(rewardPeriod);
    // }

    /**
    * @dev Returns gold reward per period.
    @param _goldRewardsPerPeriod Returns reward per period 
    */  
    function getGoldRewardsPerPeriod() public view returns(uint256 _goldRewardsPerPeriod) {
        return goldRewardsPerPeriod;
    }
    /**
    * @dev Returns gold reward per period.
    @param _goldRewardsPerPeriod Returns reward per period 
    */  
    function setGoldRewardsPerPeriod(uint256 _goldRewardsPerPeriod) public {
        require(settingContract == msg.sender, NOT_AUTHORIZED);
        goldRewardsPerPeriod = _goldRewardsPerPeriod;
    }
  
    /**
    * @dev Returns Setting contract address.
    @param _settingContract Setting contract address
    */  
    function getSettingContract() public view returns (address _settingContract) {
        return settingContract;
    }
    
    /**
    * @dev Sets Setting contract address. Only owner can set this value   
    @param _settingContract Setting Contract address
    */
    function setSettingContract(address _settingContract) public onlyOwner{
        settingContract = _settingContract;
    }

    // /**
    // * @dev Returns address of Booster contract.
    // @param _ouro OuroBooster contract address
    // @param _boros BorosBooster contract address
    // */
    // function getBoosters() public view returns(address _ouro, address _boros) {
    //     return (ouroBooster, borosBooster);
    // }

    /**
    * @dev Sets Booster contract address. Only setting contract can set this value   
    @param _ouro OuroBooster contract address
    @param _boros BorosBooster contract address
    */
    function setBoosters(address _ouro, address _boros) public{
        require(settingContract == msg.sender, NOT_AUTHORIZED);
        ouroBooster = _ouro;
        borosBooster = _boros;
    }

    /**
    * @dev Returns Gold chain address 
    @param _goldChainAddress Gold chain address 
    */ 
    function getGoldChainAddress() public view returns(address _goldChainAddress) {
        return goldChainAddress;
    }

    /**
    * @dev Sets Gold chain address. Only setting contract can set this value   
    @param _goldChainAddress Gold chain address
    */
    function setGoldChainAddress(address _goldChainAddress) public{
        require(settingContract == msg.sender, NOT_AUTHORIZED);
        goldChainAddress = _goldChainAddress;
    }
    /**
    * @dev Returns Compound tax amount.
    @param _compoundTax Compound tax amount 
    */  
    function getCompoundTax() public view returns(uint256 _compoundTax) {
        return compoundTax;
    }

    /**
    * @dev Sets Compound tax amount. Only setting contract can set this value   
    @param _compoundTax Compound tax amount 
    */ 
    function setCompoundTax(uint256 _compoundTax) public{
        require(settingContract == msg.sender, NOT_AUTHORIZED);
        compoundTax = _compoundTax;
    }

    /**
    * @dev Returns Gold chain address 
    @param _silverChainManager Gold chain address 
    */ 
    function getSCM() public view returns(address _silverChainManager) {
        return silverChainManager;
    }

    /**
    * @dev Sets Gold chain address. Only setting contract can set this value   
    @param _silverChainManager Gold chain address
    */
    function setSCM(address _silverChainManager) public{
        require(settingContract == msg.sender, NOT_AUTHORIZED);
        silverChainManager = _silverChainManager;
    }


    /**
    * @dev Returns Silver chain address 
    @param _silverChainAddress Silver chain address 
    */ 
    function getSilverChainAddress() public view returns(address _silverChainAddress) {
        return silverChainAddress;
    }

    /**
    * @dev Sets Silver chain address. Only setting contract can set this value   
    @param _silverChainAddress Silver chain address
    */
    function setSilverChainAddress(address _silverChainAddress) public {
        require(settingContract == msg.sender, NOT_AUTHORIZED);
        silverChainAddress = _silverChainAddress;
    }

    // /**
    // * @dev Returns Alx Token address 
    // @param _alccToken Alx Token address 
    // */
    // function getAlccToken() public view returns(address _alccToken) {
    //     return alccToken;
    // }

    /**
    * @dev Sets Alx token address. Only setting contract can set this value   
    @param _alccToken Alx Token address
    */
    function setAlccToken(address _alccToken) public {
        require(settingContract == msg.sender, NOT_AUTHORIZED);
        alccToken = _alccToken;
    }

    /**
    * @dev Returns ROI Limit for chains.
    @param _roiLimit ROI Limit 
    */  
    function getRoiLimit() public view returns(uint256 _roiLimit) {
        return roiLimit;
    }

    /**
    * @dev Sets ROI Limit for chains. Only setting contract can set this value   
    @param _roiLimit reward per period 
    */ 
    function setRoiLimit(uint256 _roiLimit) public{
        require(settingContract == msg.sender, NOT_AUTHORIZED);
        roiLimit = _roiLimit;
    }
    
    /**
    * @dev Returns USDT Token address 
    @param _usdt USDT Token address 
    */
    function getUsdt() public view returns(address _usdt) {
        return usdt;
    }

    // /**
    // * @dev Sets USDT token address. Only setting contract can set this value   
    // @param _usdt USDT Token address
    // */
    // function setUsdt(address _usdt) public {
    //     require(settingContract == msg.sender, NOT_AUTHORIZED);
    //     usdt = _usdt;
    // }

    /**
    * @dev Returns Gold claim tax amount
    @param _goldClaimTax Gold claim tax amount
    */
    function getGoldClaimTax() public view returns(uint256 _goldClaimTax) {
        return goldClaimTax;
    }

    /**
    * @dev Sets Claim tax of gold chain value. Only setting contract can set this value   
    @param _goldClaimTax Claim tax of gold chain
    */
    function setGoldClaimTax(uint256 _goldClaimTax) public {
        require(settingContract == msg.sender, NOT_AUTHORIZED);
        goldClaimTax = _goldClaimTax;
    }
           
    /**
    * @dev Returns fee amount to create Silver chain 
    @param _silverCreationFeeToken Silver chain creation feee
    */
    function getSilverCreationFeeToken() public view returns(uint256 _silverCreationFeeToken) {
        return silverCreationFeeToken;
    }

    /**
    * @dev Sets Silver chain creation fee value. Only setting contract can set this value   
    @param _silverCreationFeeToken Silver chain creation fee
    */
    function setSilverCreationFeeToken(uint256 _silverCreationFeeToken) public {
        require(settingContract == msg.sender, NOT_AUTHORIZED);
        silverCreationFeeToken = _silverCreationFeeToken;
    }

    /**
    * @dev Returns fee amount to create gold chain 
    @param _goldCreationFeeToken Gold chain creation feee
    */ 
    function getGoldCreationFeeToken() public view returns(uint256 _goldCreationFeeToken) {
        return goldCreationFeeToken;
    }

    /**
    * @dev Sets Gold chain creation fee value. Only setting contract can set this value   
    @param _goldCreationFeeToken Gold chain creation fee
    */
    function setGoldCreationFeeToken(uint256 _goldCreationFeeToken) public {
        require(settingContract == msg.sender, NOT_AUTHORIZED);
        goldCreationFeeToken = _goldCreationFeeToken;
    }
   
    // /**
    // * @dev Returns Reward period time 
    // @param _rewardPeriod Reward period
    // */
    // function getRewardPeriod() public view returns(uint256 _rewardPeriod){
    //     return rewardPeriod;
    // }

    // /**
    // * @dev Sets Reward period value. Only setting contract can set this value   
    // @param _rewardPeriod Reward period amount
    // */
    // function setRewardPeriod(uint256 _rewardPeriod) public  {
    //     require(settingContract == msg.sender, NOT_AUTHORIZED);
    //     rewardPeriod = _rewardPeriod.mul(60);
    // }

    // /**
    // * @dev Returns price to create Booster.   
    //  @param _ouroPrice OuroBooster price
    // @param _borosPrice BorosBooster price
    // */
    // function getBoosterPrice() public view returns(uint256 _ouroPrice, uint256 _borosPrice){
    //     return (ouroPrice, borosPrice);
    // }

    // /**
    // * @dev Sets Booster price value. Only setting contract can set this value   
    //  @param _ouroPrice OuroBooster price
    //  @param _borosPrice BorosBooster price
    // */
    // function setBoosterPrice(uint256 _ouroPrice, uint256 _borosPrice) public {
    //     require(settingContract == msg.sender, NOT_AUTHORIZED);
    //     ouroPrice = _ouroPrice;
    //     borosPrice = _borosPrice;
    // }

    /**
    * @dev Returns Alx to USDT rate 
    @param _alxToUsdtRate Returns Alx to USDT rate
    */
    // function getAlxToUsdtRate() public view returns(uint256 _alxToUsdtRate){
    //     return alxToUsdtRate;
    // }

    // /**
    // * @dev Sets Alx to USDT rate. Only setting contract can set this value   
    // @param _alxToUsdtRate Returns Alx to USDT rate
    // */
    // function setAlxToUsdtRate(uint256 _alxToUsdtRate) public {
    //     require(settingContract == msg.sender, NOT_AUTHORIZED);
    //     alxToUsdtRate = _alxToUsdtRate;
    // }
/////////////////// Payment methods ////////////
    // /**
    // * @dev Returns token balance of contract.   
    // @param _tokenAddress Token Address 
    // @param _balance Token Balance 
    // */
    // function getTokenBalance(address _tokenAddress) public view returns (uint256 _balance) {
    //     return IToken(_tokenAddress).balanceOf(address(this));
    // }
    // /**
    // * @dev Returns currency balance of contract.   
    // @param _balance Currency Balance 
    // */
    // function getCurrencyBalance() public view returns (uint256 _balance) {
    //     return address(this).balance;
    // }

    /**
    * @dev Withdraw any token balance from this contrat and can send to any address. Only Owner can call this method.   
    @param _tokenAddress Token Address 
    @param _destionation User address
    @param _amount Amount to withdraw
    */
    function withdrawToken(address _tokenAddress, address _destionation, uint256 _amount) public onlyOwner{
        // uint256 tokenBalance = IToken(_tokenAddress).balanceOf(address(this));
        // require(tokenBalance > 0, NO_TOKENS);
        IERC20(_tokenAddress).transfer(_destionation, _amount);
    }

    /**
    * @dev Withdraw currency balance from this contrat and can send to any address. Only Owner can call this method.   
    @param _destionation User addres
    @param _amount Amount to withdraw
    */
    function withdrawCurrency(address _destionation, uint256 _amount) public onlyOwner {
        // require(address(this).balance > 0, NO_CURRENCY);
        payable(_destionation).transfer(_amount);
    }

    receive() external payable {
    }

    fallback() external payable {
    }
}