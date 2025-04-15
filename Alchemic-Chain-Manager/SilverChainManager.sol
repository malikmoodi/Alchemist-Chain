
// SPDX-License-Identifier: MIT

pragma  solidity 0.8.7;

import "../Interface/IBooster.sol";
import "../Interface/IChains.sol";
import "../Interface/IERC20.sol";
import "../HelperContracts/SafeMath.sol";
import "../Interface/IManagers.sol";
import "../Interface/ITimer.sol";
import "../Interface/IToken.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract SilverChainManager is Initializable, OwnableUpgradeable, UUPSUpgradeable{
    using SafeMath for uint256;

    event paymentRecieved(address sender, uint256 amount);
    event fallbackCalled(address sender, uint256 amount);
    event chainCreated(address to, string name, uint256 tokenId);

    mapping (uint256 => uint256) private daysOverDue; 
    mapping (uint256 => uint256) private tokenLastUpkeepTime; 
    mapping (uint256 => uint256) public tokenLastActionDay;
    mapping (address => uint256) private userLastActionDay;
    
    address private ouroBooster;
    address private borosBooster;
    address private alccToken;
    address private usdt;
    address private silverChainAddress;
    address private goldChainManager;
    address private timerContract;
    address private settingContract;

    uint256 private rewardPeriod;
    uint256 private silverCreationFeeToken;  
    uint256 private silverCreationFeeUsdt;  
    uint256 private silverRewardsPerPeriod;
    uint256 private silverClaimTax;
    uint256 private compoundTax;
    // uint256 private startTime; 
    uint256 private upKeepCycleSilver;
    uint256 private alxToUsdtRate;

    uint256 private upkeepPercentage;
    uint256 private ouroRewardBenefit;
    uint256 private ouroUpkeepReduction;
    uint256 private ouroPrice;

    uint256 private borosRewardBenefit;
    uint256 private borosUpkeepReduction;
    uint256 private borosPrice;

    uint256 private ouroborosRewardBenefit;
    uint256 private ouroborosUpkeepReduction;

    uint256 private roiLimit;

    uint256 private usdtLqLimit;
    address private liquidityHelper;

    string constant TOKEN_NOT_APPROVED = "SCM1";
    string constant TOTAL_TOKEN_NOT_APPROVED = "SCM2";
    string constant ONE_ACTION_PER_DAY_ALLOWED = "SCM3";
    string constant UPKEEP_NOT_PAID = "SCM4";
    string constant USER_IS_NOT_OWNER = "SCM5";
    string constant NOT_ENOUGH_TOKENS = "SCM6";
    string constant NOT_AUTHORIZED = "SCM7";
    string constant USER_ONLY_ONE_ACTION_IN_DAY = "SCM8";
    string constant TOKEN_ONLY_ONE_ACTION_IN_DAY = "SCM9";
    string constant LESS_AMOUNT_TO_COMPOUND = "SCM10";
    string constant NO_TOKENS = "SCM11";
    string constant NO_CURRENCY = "SCM12";
    string constant USER_CHAIN_REACH_ROI = "SCM13";

    /**
        * @dev Initialize: Deploy Alchemic Silver Chain Manager and set the basic values 
        @param _alccToken Contract address of Alx token
        @param _usdt Contract address of USDT token
        @param _silverChainAddress Contract address of Alchemic Silver Chain
        *
    */
    function initialize(address _alccToken, address _usdt, address _silverChainAddress, 
        address _settingContract, address _ouro, address _boros, address _liquidityHelper, address _timer) initializer public {
        __Ownable_init();
        __UUPSUpgradeable_init();

        silverChainAddress= _silverChainAddress;
        alccToken = _alccToken;
        usdt = _usdt;
        ouroBooster = _ouro;
        borosBooster = _boros;
        timerContract = _timer;
        settingContract = _settingContract;
        liquidityHelper = _liquidityHelper;

        upKeepCycleSilver =  7; //7DAYS
        // startTime = ITimer(timerContract).getDay(); 
        rewardPeriod = 5 minutes; //1DAY
        alxToUsdtRate = 10;
        roiLimit= 200;
        
        silverCreationFeeToken = 10*(10**18);
        silverCreationFeeUsdt = 10*(10**18);
        silverRewardsPerPeriod = 4*(10**17); // 0.4 per day
        silverClaimTax = 15;

        compoundTax = 5;
        
        upkeepPercentage = 10; /// upkeep will be 10% of all rewards, in usdt
        ouroborosRewardBenefit = 10;
        ouroborosUpkeepReduction = 5;

        ouroRewardBenefit = 5;
        ouroUpkeepReduction = 2;
        ouroPrice = 800*(10**18);

        borosRewardBenefit = 2;
        borosUpkeepReduction = 1;
        borosPrice = 400*(10**18);
    }

    function _authorizeUpgrade(address newImplementation)internal onlyOwner override{}

    /**
        * @dev createSilverChain: To create silver chain this method transfer tokens amount(silverCreationFeeToken) from user to this contract. At time of creation it emits an event chainCreated with User's address, name of chain and token Id of chain.
        @param name Name of chain
    */
    function createSilverChain(string memory name) public {
        require (IToken(alccToken).allowance(msg.sender,address(this)) >= silverCreationFeeToken, TOKEN_NOT_APPROVED);
        require (IToken(usdt).allowance(msg.sender,address(this)) >= silverCreationFeeUsdt, TOKEN_NOT_APPROVED);
        require(!userChainReachROI(msg.sender), USER_CHAIN_REACH_ROI);
        
        IToken(alccToken).transferFrom(msg.sender, address(this), silverCreationFeeToken);
        IToken(usdt).transferFrom(msg.sender, address(this), silverCreationFeeUsdt);
        uint256 tokenId = IChains(silverChainAddress).createChain(msg.sender, name);
        emit chainCreated(msg.sender, name, tokenId);
        transferToLiquidityHelper();
        
        tokenLastUpkeepTime[tokenId] = ITimer(timerContract).getDay();        
    }

    function createGCM(address _user, string memory name) public returns(uint256 _tokenId) {
        require (msg.sender == goldChainManager, NOT_AUTHORIZED);
        uint256 tokenId = IChains(silverChainAddress).createChain(_user, name);
        emit chainCreated(_user, name, tokenId);

        tokenLastUpkeepTime[tokenId] = ITimer(timerContract).getDay();        
        return tokenId;
    }

    /**
        * @dev createMultipleSilverChain: To create multiple silver chain this method transfer tokens amount(silverCreationFeeToken multiply by number of chains) from user to this contract. And create the chains by passing call
        to Alchemic silver chain. At each creation of chain it emits an event chainCreated with User's address, name of chain and token Id of chain.
        @param name Name of chain sets this name to all chains
        @param numberOfChains Number of chains to create 
    */
    function createMultipleSilverChain(string memory name, uint256 numberOfChains) public {
        uint256 totalTokenFee = silverCreationFeeToken.mul(numberOfChains);
        uint256 totalUsdtFee = silverCreationFeeUsdt.mul(numberOfChains);
        require (IToken(alccToken).allowance(msg.sender, address(this)) >= totalTokenFee, TOTAL_TOKEN_NOT_APPROVED);
        require(!userChainReachROI(msg.sender), USER_CHAIN_REACH_ROI);
        require (IToken(usdt).allowance(msg.sender, address(this)) >= totalUsdtFee, TOTAL_TOKEN_NOT_APPROVED);
        IToken(alccToken).transferFrom(msg.sender, address(this), totalTokenFee);
        IToken(usdt).transferFrom(msg.sender, address(this), totalUsdtFee);
        // transferToLiquidityHelper();
        for(uint256 i = 0 ; i < numberOfChains; i ++){
            uint256 tokenId = IChains(silverChainAddress).createChain(msg.sender, name);
            emit chainCreated(msg.sender, name, tokenId);
            tokenLastUpkeepTime[tokenId] = ITimer(timerContract).getDay();
        }
        transferToLiquidityHelper();
    }

    function getCompoundTaxValue(address _user) public view returns(uint256 taxInUsdt){
        (uint256 rewardToMint, )= calculateAllSilverReward(_user);
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
        uint256[] memory chains = IChains(silverChainAddress).getUserChains(msg.sender);

        // uint256 rewardDiff;
        (uint256 rewardToMint, ) = calculateAllSilverReward(msg.sender); 
        uint256 usdtAmount = getCompoundTaxValue(msg.sender);

        IToken(usdt).transferFrom(msg.sender, address(this), silverCreationFeeUsdt.mul(numberOfCompounds).add(usdtAmount));

        uint256 totalAmount;
        uint256 amountDiff;
        uint256 claimedAmount;

        IToken(alccToken).distributeReward(rewardToMint);       

        if(rewardToMint > silverCreationFeeToken.mul(numberOfCompounds)){
            amountDiff = rewardToMint.sub(silverCreationFeeToken.mul(numberOfCompounds));
            // amountDiff = amountDiff.sub((amountDiff.mul(silverClaimTax)).div(100));
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
                uint256 b = silverClaimTax;

                if(a > 99 && a < 150 ){
                    b = 55;
                    transferClaim = claimedAmount.sub((b).mul(claimedAmount.div(100))); 
                }else if(a >= 150 ){
                    transferClaim = 0;
                }else{
                    transferClaim = claimedAmount.sub((b).mul(claimedAmount.div(100))); 
                }
                totalClaimed += transferClaim;
            }

            IChains(silverChainAddress).claimRewardsToken(chains[i], transferClaim);
            
            daysOverDue[chains[i]] = 0;
            tokenLastActionDay[chains[i]] = ITimer(timerContract).getDay();
        }
        amountDiff = totalClaimed;
        
        if(amountDiff > 0){ /// ask supervisor to add booster benefit here, if wee add booster benefit here then we need to differntiate between token amount and excess reward amount
            IToken(alccToken).transfer(msg.sender, amountDiff);
        }
        for(uint256 i = 0 ; i < numberOfCompounds; i ++){
            uint256 tokenId = IChains(silverChainAddress).createChain(msg.sender, name);
            emit chainCreated(msg.sender, name, tokenId);
            tokenLastUpkeepTime[tokenId] = ITimer(timerContract).getDay();
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

    function getourodays(address user) public view returns(uint256){
        return IBooster(ouroBooster).getUserBoosterDay(user);
    }

    function getborosdays(address user) public view returns(uint256){
        return IBooster(borosBooster).getUserBoosterDay(user);
    }
    // function getborosdays(address user) public view returns(uint256){
    //     return IBooster(borosBooster).getUserBoosterDay(user);
    // }
    function getRewardsToTransfer(uint256 rewardToMint, address _user) public view returns(uint256 _rewardToMint){
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

    function addBoosterWise(uint256 rewardToMint, uint256 tokenId) private view returns(uint256 _rewardToMint){
        address _user = IChains(silverChainAddress).ownerOf(tokenId);

        bool ouroStatus = IBooster(ouroBooster).balanceOf(_user) > 0 ;
        bool borosStatus = IBooster(borosBooster).balanceOf(_user) > 0 ;

        uint256 ouroPurchaseDay = IBooster(ouroBooster).getBoosterPurchaseDay(_user);
        uint256 borosPurchaseDay = IBooster(borosBooster).getBoosterPurchaseDay(_user);
        uint256 ouroSellDay = IBooster(ouroBooster).getBoosterSellDay(_user);
        uint256 borosSellDay = IBooster(borosBooster).getBoosterSellDay(_user);        

        if(!borosStatus && borosSellDay <= tokenLastUpkeepTime[tokenId]){
            if(ouroPurchaseDay <= tokenLastUpkeepTime[tokenId] && ouroStatus){
                rewardToMint = rewardToMint.add((ouroRewardBenefit).mul(rewardToMint.div(100)));                 
            }
        }
        // rewardToMint = getRewardsToTransfer(rewardToMint, _user);
    }

    function calculateAdvancedRoi(uint256 _rewardToMint, uint256 tokenId) private view returns(uint256 roiPercent){
        _rewardToMint = _rewardToMint.sub((_rewardToMint.mul(silverClaimTax)).div(100));
        uint256 claimedAmount = IChains(silverChainAddress).getTotalClaimAmount(tokenId);
        uint256 total = _rewardToMint.add(claimedAmount);
        total = total.sub((total.mul(silverClaimTax)).div(100));
        roiPercent = ((total.mul(alxToUsdtRate)).mul(100)).div(getSilverChainCostUsdt());
        return roiPercent;
    }

    /**
        @dev calculateRewardsSilver: Calculates reward of specific silver chain.
        @param tokenId Token id of chain
        @param rewardToMint Calculated reward of chain to Mint
        @param rewardToTransfer Final amount to transfer
    */
    function calculateRewardsSilver(uint256 tokenId)public view returns(uint256 rewardToMint, uint256 rewardToTransfer){
        rewardToMint = IChains(silverChainAddress).calculateRewardsToken(tokenId);
        address user = IChains(silverChainAddress).ownerOf(tokenId);

        uint256 totalDays = daysOverDue[tokenId]; 

        if(ITimer(timerContract).getDay() > tokenLastUpkeepTime[tokenId].add(upKeepCycleSilver)){
            uint256 time = (ITimer(timerContract).getDay().sub(tokenLastUpkeepTime[tokenId].add(upKeepCycleSilver)));
            // .div(rewardPeriod); 
            totalDays  += time;  
        }

        if(totalDays.mul(silverRewardsPerPeriod) > rewardToMint){
            return (0,0);
        }

        // if(calculateRoi(tokenId) > 199){
        if(calculateRoi(tokenId) > 149){
            return (0,0);
        }

        rewardToMint = rewardToMint.sub(totalDays.mul(silverRewardsPerPeriod));
        rewardToMint = getRewardsToTransfer(rewardToMint, user);
        uint256 a = calculateAdvancedRoi(rewardToMint, tokenId); 
        uint256 b = silverClaimTax;

        if(a > 99){
            b = 55;
        }

        rewardToTransfer = rewardToMint.sub((b).mul(rewardToMint.div(100))); 

        uint256 claimedAmount = IChains(silverChainAddress).getTotalClaimAmount(tokenId);
        claimedAmount = claimedAmount.sub((claimedAmount.mul(silverClaimTax)).div(100));

        uint256 total = claimedAmount.add(rewardToTransfer);
        uint256 maxRoiPrice = ((getSilverChainCostUsdt().mul(getRoiLimit())).div(100)).div(alxToUsdtRate);

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
        @dev Returns upkeep amount of specfic silver chain of user.
        @param upkeepFee Upkeep fee amount of silver chain
        @param tokenId Token id of chain
    */
    function getTokenUpKeepFeeSilver(uint256 tokenId) public view returns(uint256 upkeepFee){
        uint256 rewards;
        address user = IChains(silverChainAddress).ownerOf(tokenId);

        if(calculateRoi(tokenId) > 150){
            return (0);
        }

        if(isUpKeepPaid(tokenId)){
            uint256 timeSinceUpkeep = (ITimer(timerContract).getDay().sub(tokenLastUpkeepTime[tokenId]));
            // .div(rewardPeriod);
            rewards = silverRewardsPerPeriod.mul(timeSinceUpkeep);
        }else {
            rewards = silverRewardsPerPeriod.mul(upKeepCycleSilver);
            // .div(rewardPeriod));
        }
        upkeepFee = getUpkeepFeePVT(rewards, user);
            // upkeepFee = (upkeepPercentage.mul(rewards)).div(100);

        return upkeepFee.mul(alxToUsdtRate);
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

    /**
        @dev Returns upkeep amount of all silver chains of user.
        @param _upkeepFeeAll Total Upkeep amount of all silver chains
    */
    function getUpKeepFeeAllSilver(address user) public view returns(uint256 _upkeepFeeAll){
        uint256 upkeepFeeAll;
        uint256[] memory tokenId = IChains(silverChainAddress).getUserChains(user);

        for(uint256 i; i < tokenId.length; i++){
            upkeepFeeAll += getTokenUpKeepFeeSilver(tokenId[i]);
        }      

        return upkeepFeeAll;
    }

    /**
        @dev Calculates ROI of specific token id.
        @param tokenId Token id of chain
        @param roiPercent ROI Percentage
    */
    function calculateRoi(uint256 tokenId) public view returns(uint256 roiPercent){
        uint256 claimedAmount = IChains(silverChainAddress).getTotalClaimAmount(tokenId);
        claimedAmount = claimedAmount.sub((claimedAmount.mul(silverClaimTax)).div(100));
        uint256 maxRoiPrice = ((getSilverChainCostUsdt().mul(getRoiLimit())).div(100)).div(alxToUsdtRate);

        if(claimedAmount > maxRoiPrice.sub(5*10**17)){
            roiPercent = (((claimedAmount.mul(alxToUsdtRate)).mul(100)).div(getSilverChainCostUsdt())).add(1);
        }else{
            roiPercent = ((claimedAmount.mul(alxToUsdtRate)).mul(100)).div(getSilverChainCostUsdt());
        }
    }

    /**
        @dev calculateAllSilverReward: Calculates reward of all silver chains of user.
        @param user Chains owner address
        @param _rewardToMint Calculated all reward of chains to mint
        @param _rewardToTransfer Calculated all reward of chains to transfer
    */
    function calculateAllSilverReward(address user) public view returns(uint256 _rewardToMint, uint256 _rewardToTransfer) {
        uint256[] memory chains = IChains(silverChainAddress).getUserChains(user);
        uint256 rewardToMint;
        uint256 rewardToTransfer;
        for (uint i = 0 ; i < chains.length; i++){
            (rewardToMint, rewardToTransfer) = calculateRewardsSilver(chains[i]);
            _rewardToMint += rewardToMint;
           _rewardToTransfer += rewardToTransfer;
        }
        return (_rewardToMint, _rewardToTransfer);
    }

    /**
        @dev claimRewardsSilver: Claim amount of chain and transfer alx token to owner of chain.
        @param tokenId Token id of chain
        @param _claimedAmount Claimed amount of chain
    */
    function claimRewardsSilver(uint256 tokenId) public returns (uint256 _claimedAmount){
        require(tokenLastActionDay[tokenId] != ITimer(timerContract).getDay(), TOKEN_ONLY_ONE_ACTION_IN_DAY);
        require(userLastActionDay[msg.sender] != ITimer(timerContract).getDay(), USER_ONLY_ONE_ACTION_IN_DAY);
        _claimedAmount = claimReward(tokenId);
        transferToLiquidityHelper();
        return _claimedAmount;
    }

    function claimReward(uint256 tokenId) private returns(uint256 _claimedAmount){
        require(isUpKeepPaid(tokenId), UPKEEP_NOT_PAID);  
        require(IChains(silverChainAddress).ownerOf(tokenId) == msg.sender, USER_IS_NOT_OWNER);
        (uint256 rewardToMint, uint256 rewardToTransfer) = calculateRewardsSilver(tokenId);
        if(rewardToMint > 0){
            IToken(alccToken).distributeReward(rewardToMint);
            IChains(silverChainAddress).claimRewardsToken(tokenId, rewardToTransfer);
            
            // IToken(alccToken).transfer(IChains(silverChainAddress).ownerOf(tokenId), rewardToTransfer);
            IToken(alccToken).transfer(msg.sender, rewardToTransfer);
            
            daysOverDue[tokenId] = 0;
            tokenLastActionDay[tokenId] = ITimer(timerContract).getDay();
        }
        return rewardToTransfer;
    }

    /**
        @dev claimAllSilver: Claims reward of all silver chain of user, and transfer alx token to owner of chains.
        @param _totalClaimedAmount Total claimed amount of chains
    */
    function claimAllSilver(address user) public returns(uint256 _totalClaimedAmount) {
        require(userLastActionDay[user] != ITimer(timerContract).getDay(), USER_ONLY_ONE_ACTION_IN_DAY);
        uint256[] memory chains = IChains(silverChainAddress).getUserChains(user);
        uint256 totalClaimedAmount = 0;

        for (uint i = 0 ; i < chains.length; i++){
            if(calculateRoi(chains[i]) < getRoiLimit()){
                if(tokenLastActionDay[chains[i]] != ITimer(timerContract).getDay()){
                    totalClaimedAmount += claimReward(chains[i]);   
                }
            }
        }
        userLastActionDay[user] = ITimer(timerContract).getDay();
        transferToLiquidityHelper();
        return totalClaimedAmount;
    }

    /**
        @dev User pay upkeep of all silver chains. And amount of total upkeep transfer from user to contract
        @param user User's address
    */
    function payUpKeepFeeAllSilver(address user) public {
        uint256[] memory tokenId = IChains(silverChainAddress).getUserChains(user);

        for(uint256 i; i < tokenId.length; i++){
            if(calculateRoi(tokenId[i]) < getRoiLimit()){
                payUpkeepPVT(tokenId[i]);
            }
        }
        transferToLiquidityHelper();

    }

    function payUpkeepPVT(uint256 tokenId)private{
        uint256 fee = getTokenUpKeepFeeSilver(tokenId);
        if(fee > 0){
            IToken(usdt).transferFrom(msg.sender,address(this),fee);
            if(ITimer(timerContract).getDay() > tokenLastUpkeepTime[tokenId].add(upKeepCycleSilver)){
                uint256 Days = (ITimer(timerContract).getDay() - (tokenLastUpkeepTime[tokenId].add(upKeepCycleSilver)));
                // .div(rewardPeriod);
                daysOverDue[tokenId] += Days;
            }
            tokenLastUpkeepTime[tokenId]= ITimer(timerContract).getDay();
        }

    }

    /**
        @dev User pay upkeep of specific silver chain. And amount of upkeep transfer from user to contract
        @param tokenId Token id of chain
    */
    function payUpKeepFeeSilver(uint256 tokenId) public {
        payUpkeepPVT(tokenId);    
        transferToLiquidityHelper();
    }

    /**
        @dev Returns upkeep amount of specfic silver chain is paid or unpaid.
        @param tokenId Token id of chain
        @param upkeepStatus Upkeep paid or unpaid
    */
    function isUpKeepPaid(uint256 tokenId) public view returns(bool upkeepStatus){
        uint256 feeTime = tokenLastUpkeepTime[tokenId];
        if(calculateRoi(tokenId) >= getRoiLimit()){
            return true;
        }else{
            return (feeTime.add(upKeepCycleSilver)) >= ITimer(timerContract).getDay(); 
        }
    }

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
        uint256[] memory chains = IChains(silverChainAddress).getUserChains(_user);
        for(uint i; i < chains.length; i++){
            if(calculateRoi(chains[i]) > roiLimit){
                return true;
            }
        }
        return false;
    }
    
    function getUsdtLqLimit() public view returns(uint256 _usdtLqLimit) {
        return usdtLqLimit;
    }

    function setUsdtLqLimit(uint256 _usdtLqLimit) public{
        require(settingContract == msg.sender, NOT_AUTHORIZED);
        usdtLqLimit = _usdtLqLimit;
    }
    
    function setLiquidityHelper(address _liquidityHelper) public {
        require(settingContract == msg.sender, NOT_AUTHORIZED);
        liquidityHelper = _liquidityHelper;
    }

    function getLiquidityHelper() public view returns(address _liquidityHelper){
        return liquidityHelper;
    }

    function getSilverChainCostUsdt() public view returns(uint256 _cost){
        uint256 cost = silverCreationFeeUsdt.add(silverCreationFeeToken.mul(alxToUsdtRate));
        return cost;
    }

    /**
        * @dev Returns Silver chain manager contract address.     
        @param _timerContract Silver chain manager contract address
    */ 
    function getTimerContract() public view returns (address _timerContract) {
        return timerContract;
    }

    /**
        * @dev Sets Silver chain manager address. Only Setting contract can call this method.     
        @param _timerContract Silver chain manager address
    */ 
    function setTimerContract(address _timerContract) public {
        require(settingContract == msg.sender, NOT_AUTHORIZED);
        timerContract = _timerContract;
    }
    
    /**
        * @dev Returns silver creation fee in usdt.
        @param _silverCreationFeeUsdt Creation fee in usdt 
    */  
    function getSilverCreationFeeUsdt() public view returns(uint256 _silverCreationFeeUsdt) {
        return silverCreationFeeUsdt;
    }

    /**
    * @dev Sets silver creation fee in usdt. Only setting contract can set this value   
    @param _silverCreationFeeUsdt Creation fee in usdt 
    */ 
    function setSilverCreationFeeUsdt(uint256 _silverCreationFeeUsdt) public{
        require(settingContract == msg.sender, NOT_AUTHORIZED);
        silverCreationFeeUsdt = _silverCreationFeeUsdt;
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
        if(ITimer(timerContract).getDay() < (tokenLastUpkeepTime[tokenId].add(upKeepCycleSilver))){
            return (tokenLastUpkeepTime[tokenId].add(upKeepCycleSilver)).sub(ITimer(timerContract).getDay());
        }
        return 0; 
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
    * @dev Returns silver upkeep cycle.
    @param _silverUpkeepCycle Upkeep cycle in days 
    */  
    function getSilverUpkeepCycle() public view returns(uint256 _silverUpkeepCycle) {
        return upKeepCycleSilver;
    }

    /**
    * @dev Sets silver upkeep cycle. Only setting contract can set this value   
    @param _silverUpkeepCycle Upkeep cycle in days 
    */ 
    function setSilverUpkeepCycle(uint256 _silverUpkeepCycle) public{
        require(settingContract == msg.sender, NOT_AUTHORIZED);
        // upKeepCycleSilver = _silverUpkeepCycle.mul(rewardPeriod);
        upKeepCycleSilver = _silverUpkeepCycle;
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
    * @dev Returns silver reward per period.
    @param _silverRewardsPerPeriod Returns reward per period 
    */  
    function getSilverRewardsPerPeriod() public view returns(uint256 _silverRewardsPerPeriod) {
        return silverRewardsPerPeriod;
    }

    /**
    * @dev Sets silver reward per period. Only setting contract can set this value   
    @param _silverRewardsPerPeriod reward per period 
    */ 
    function setSilverRewardsPerPeriod(uint256 _silverRewardsPerPeriod) public{
        require(settingContract == msg.sender, NOT_AUTHORIZED);
        silverRewardsPerPeriod = _silverRewardsPerPeriod;
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

    /**
    * @dev Returns Alx to USDT rate 
    @param _alxToUsdtRate Returns Alx to USDT rate
    */
    function getAlxToUsdtRate() public view returns(uint256 _alxToUsdtRate){
        return alxToUsdtRate;
    }

    /**
    * @dev Sets Alx to USDT rate. Only setting contract can set this value   
    @param _alxToUsdtRate Returns Alx to USDT rate
    */
    function setAlxToUsdtRate(uint256 _alxToUsdtRate) public {
        require(settingContract == msg.sender, NOT_AUTHORIZED);
        alxToUsdtRate = _alxToUsdtRate;
    }


    // /**
    // * @dev Returns Alx Token address 
    // @param _goldChainManager Alx Token address 
    // */
    // function getGCM() public view returns(address _goldChainManager) {
    //     return goldChainManager;
    // }

    /**
    * @dev Sets Alx token address. Only setting contract can set this value   
    @param _goldChainManager Alx Token address
    */
    function setGCM(address _goldChainManager) public  {
        require(settingContract == msg.sender, NOT_AUTHORIZED);
        goldChainManager = _goldChainManager;
    }
    /**
    * @dev Returns Alx Token address 
    @param _alccToken Alx Token address 
    */
    function getAlccToken() public view returns(address _alccToken) {
        return alccToken;
    }

    /**
    * @dev Sets Alx token address. Only setting contract can set this value   
    @param _alccToken Alx Token address
    */
    function setAlccToken(address _alccToken) public  {
        require(settingContract == msg.sender, NOT_AUTHORIZED);
        alccToken = _alccToken;
    }

    // /**
    // * @dev Returns USDT Token address 
    // @param _usdt USDT Token address 
    // */
    // function getUsdt() public view returns(address _usdt) {
    //     return usdt;
    // }

    /**
    * @dev Sets USDT token address. Only setting contract can set this value   
    @param _usdt USDT Token address
    */
    function setUsdt(address _usdt) public {
        require(settingContract == msg.sender, NOT_AUTHORIZED);
        usdt = _usdt;
    }

    /**
    * @dev Returns Silver claim tax amount
    @param _silverClaimTax Silver claim tax amount
    */
    function getSilverClaimTax() public view returns(uint256 _silverClaimTax) {
        return silverClaimTax;
    }

    /**
    * @dev Sets Claim tax of silver chain value. Only setting contract can set this value   
    @param _silverClaimTax Claim tax of silver chain
    */
    function setSilverClaimTax(uint256 _silverClaimTax) public{
        require(settingContract == msg.sender, NOT_AUTHORIZED);
        silverClaimTax = _silverClaimTax;
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
    // function setRewardPeriod(uint256 _rewardPeriod) public {
    //     require(settingContract == msg.sender, NOT_AUTHORIZED);
    //     rewardPeriod = _rewardPeriod.mul(60);
    // }

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

    /**
    * @dev Returns address of Booster contract.
    @param _ouro OuroBooster contract address
    @param _boros BorosBooster contract address
    */
    function getBoosters() public view returns(address _ouro, address _boros) {
        return (ouroBooster, borosBooster);
    }

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
/////////////////// Payment methods ////////////
    /**
    * @dev Returns token balance of contract.   
    @param _tokenAddress Token Address 
    @param _balance Token Balance 
    */
    function getTokenBalance(address _tokenAddress) public view returns (uint256 _balance) {
        return IToken(_tokenAddress).balanceOf(address(this));
    }
    /**
    * @dev Returns currency balance of contract.   
    @param _balance Currency Balance 
    */
    function getCurrencyBalance() public view returns (uint256 _balance) {
        return address(this).balance;
    }

    /**
    * @dev Withdraw any token balance from this contrat and can send to any address. Only Owner can call this method.   
    @param _tokenAddress Token Address 
    @param _destionation User address
    @param _amount Amount to withdraw
    */
    function withdrawToken(address _tokenAddress, address _destionation, uint256 _amount) public onlyOwner{
        IToken(_tokenAddress).transfer(_destionation, _amount);
    }

    /**
    * @dev Withdraw currency balance from this contrat and can send to any address. Only Owner can call this method.   
    @param _destionation User addres
    @param _amount Amount to withdraw
    */
    function withdrawCurrency(address _destionation, uint256 _amount) public onlyOwner {
        payable(_destionation).transfer(_amount);
    }

    receive() external payable {
        emit paymentRecieved(msg.sender, msg.value);
    }

    fallback() external payable {
        emit fallbackCalled(msg.sender, msg.value);
    }
}