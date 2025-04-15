// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "./contracts-upgradeable/security/PausableUpgradeable.sol";
import "./contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./contracts-upgradeable/proxy/utils/Initializable.sol";
import "./contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./IPriceOracle.sol";
import "./IUniswapV2Pair.sol";
import "./IERC20.sol";
import "./SafeMath.sol";
import "./IUniswapV2Router02.sol";
import "./IUniswapV2Factory.sol";
import "./IPriceOracle.sol";

contract AlchemicToken is Initializable, ERC20Upgradeable, PausableUpgradeable, OwnableUpgradeable, UUPSUpgradeable {
    /// @custom:oz-upgrades-unsafe-allow constructor

    using SafeMath for uint256;
    mapping (address => bool) private _iswhitelistAddress;
    mapping (address => bool) private _isExcluded;
    mapping (address => mapping (address => uint256)) private _allowances;
    mapping (address => bool) private _isExcludedFromAutoLiquidity;
    mapping (address => bool) private _isBlackListed;

    address[] private _excluded;
    address private _miscWallet;
    address private _treasuryWallet;

    uint256 private _taxFee;
    uint256 private _buyTax;  //      = 2;
    uint256 private _sellTax;  //     =2;
    uint256 private _transferTax; //=2;

    address private _token;

    uint256 private _minTokenBalance;// = 100000 * 10**18;

    IUniswapV2Router02 private _uniswapV2Router;
    address            private _uniswapV2Pair;

    address private liquidityAddress;
    address private operator;

    address private silverChainManager; 
    address private goldChainManager;

    IPriceOracle private _priceOracle;

    constructor() {
        _disableInitializers();
    }

    function initialize(address cOwner, address treasuryWallet, address miscWallet , address _operator) initializer public {
        __ERC20_init("Alchemic Token", "$ALCC");
        __Pausable_init();
        __Ownable_init();
        __UUPSUpgradeable_init();

        _buyTax        = 15;
        _sellTax       = 15;
        _transferTax   = 15;

        operator = _operator;
        _minTokenBalance = 1*10**18;

        transferOwnership(cOwner);
        _treasuryWallet = treasuryWallet;
        _miscWallet= miscWallet;

        _iswhitelistAddress[owner()]        = true;
        _iswhitelistAddress[address(this)]  = true;
        _iswhitelistAddress[_treasuryWallet]     = true;
        _iswhitelistAddress[_miscWallet]     = true;

        _token = 0x55d398326f99059fF775485246999027B3197955; // USDT BSC Mainnet

        // IUniswapV2Router02 uniswapV2Router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);// Ether router 
        //IUniswapV2Router02 uniswapV2Router = IUniswapV2Router02(0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3); // BSC Testnet
        IUniswapV2Router02 uniswapV2Router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E); // BSC Mainnet
        // IUniswapV2Router02 uniswapV2Router = IUniswapV2Router02(0x5dC5431D67cA080b7c4bf7CB77f1B3e6FeD0F1AC);   //RLC TestRouter
        // IUniswapV2Router02 uniswapV2Router = IUniswapV2Router02(0xC6A32f7c1796E699f97D89A75DDD2C0e8Ca8358A);   //RLC mainnet Router

         _uniswapV2Router = uniswapV2Router;
        _uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory())
            .createPair(address(this), _token);   //Change Addres

        _isExcludedFromAutoLiquidity[_uniswapV2Pair]            = true;
        _isExcludedFromAutoLiquidity[address(_uniswapV2Router)] = true;

    
        _mint(miscWallet, 100000 * 10 ** decimals());
    }

    function getWhiteListUser(address account) public view returns(bool) {
        return _iswhitelistAddress[account];
    }

    function addWhiteListUser(address account) public onlyOwner {
        _iswhitelistAddress[account] = true;
    }

    function removeWhiteListUser(address account) public onlyOwner{
        _iswhitelistAddress[account] = false;
    }

    function isBlackListed(address account) public view returns(bool){
        return _isBlackListed[account];
    }
    
    function removeFromBlacklist(address account) public onlyOwner {
        _isBlackListed[account]= false;
    }

    function addToBlackList(address account) public onlyOwner{
        _isBlackListed[account]= true;
    }

    function getMinTokenBalance() external view returns(uint256){
        return _minTokenBalance; 
    }

    function setMinTokenBalance(uint256 mintokenBalance) external onlyOwner{
        _minTokenBalance = mintokenBalance;
    }

    function getBuyTax() external view returns(uint256){
        return _buyTax;
    }

    function getSellTax() external view returns(uint256){
        return _sellTax;
    }

    function getTransferTax() external view returns(uint256){
        return _transferTax;
    }
    
    function setTransferTaxFeePercent(uint256 transferTax) external onlyOwner {
        _transferTax = transferTax;
    }

    function setSaleTaxFeePercent(uint256 sellTax) external onlyOwner{
        _sellTax = sellTax;
    }

    function setBuyTaxFeePercent(uint256 buyTax) external onlyOwner{
        _buyTax = buyTax;
    }
   
    /////////////////////////////////////////////////

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }


    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        override
    {
        if(_iswhitelistAddress[from]== true||_iswhitelistAddress[to]== true ){
            super._beforeTokenTransfer(from, to, amount);
        }
        else{
            if(paused()){
                revert("paused");
            }
            else{
                super._beforeTokenTransfer(from, to, amount);
            }
        }
    }
    function _authorizeUpgrade(address newImplementation)
        internal
        onlyOwner
        override
    {}

    receive() external payable {}
    function setUniswapPair(address p) external onlyOwner {
        _uniswapV2Pair = p;
    }

    function _transfer(
        address from,
        address to,
        uint256 amount, uint256 amount2) internal override {
        require(from != address(0), "Transfer from the zero address");
        require(to != address(0), "Transfer to the zero address");
        require(amount > 0, "Amount must be greater than zero");
        require(!_isBlackListed[from] && !_isBlackListed[to],"sender or recipient is BOT");
        /*
            - swapAndLiquify will be initiated when token balance of this contract
            has accumulated enough over the minimum number of tokens required.s
            - don't get caught in a circular liquidity event.
            - don't swapAndLiquify if sender is uniswap pair.
        */
        _beforeTokenTransfer(from, to, amount);       
        uint256 contractTokenBalance = balanceOf(address(this));
        
        
        if(contractTokenBalance >= _minTokenBalance){
            _balances[liquidityAddress]+=contractTokenBalance;
            _balances[address(this)] -=contractTokenBalance;
            
        }

        bool takeFee = true;
        if (_iswhitelistAddress[from] || _iswhitelistAddress[to]) {
            takeFee = false;
        }
        _tokenTransfer(from, to, amount, takeFee);

        _afterTokenTransfer(from, to, amount);
    }

    function _tokenTransfer(address sender, address recipient, uint256 amount,bool takeFee) private {
        if(sender == _uniswapV2Pair){
            _taxFee = _buyTax;
        }
        else if(recipient == _uniswapV2Pair){
            _taxFee = _sellTax;
        }
        else{
            _taxFee = _transferTax;
        }
        
        if (!takeFee) {
            _taxFee       = 0;
        }

        _transferBothExcluded(sender, recipient, amount,_taxFee);
        
    }
    function calculateFee(uint256 amount, uint256 fee) private pure returns (uint256) {
        return amount.mul(fee).div(100);
    }

    function _transferBothExcluded(address sender, address recipient, uint256 tAmount, uint256 tfee) private {
        uint256 fee = calculateFee(tAmount, tfee);

        // _balances[sender] = _balances[sender].sub(tAmount);
        // _balances[recipient] = _balances[recipient].add(tAmount-fee);
        super._transfer(sender, recipient, tAmount, tAmount-fee);
        _balances[address(this)] += fee;
    }

    function setOperator(address _operator) public onlyOwner{
        operator = _operator;
    }

    function getOperator() public view returns(address){
        return operator;
    }

    function withdrawToken(address _beneficiary, uint256 _amount) public onlyOwner{
        IERC20(address(this)).transfer(_beneficiary, _amount);
    }

    function withdrawCurrency(address _destionation, uint256 _amount) public onlyOwner {
        payable(_destionation).transfer(_amount);
    }

    function getContractBalance() public view returns(uint256){
        return balanceOf(address(this));
    }

    function setLiquidityAddress(address _liquidityAddress) public onlyOwner{
        liquidityAddress = _liquidityAddress;   
    }

    function getLiquidityAddress() public view returns (address _liquidityAddress){
        return liquidityAddress;
    }

    function setSecondToken(address token) public onlyOwner{
        _token = token;   
    }

    function getSecondToken() public view returns (address token){
        return _token;
    }

    function distributeReward(uint256 amount) public {
        require(msg.sender == silverChainManager || msg.sender == goldChainManager || msg.sender == operator, "not authorized");
        _mint(msg.sender, amount);
    }

    function setManagers(address _silverChainManager, address _goldChainManager) public onlyOwner{
        silverChainManager = _silverChainManager;
        goldChainManager = _goldChainManager;
    }

    function getManagers() public view returns(address _silverChainManager, address _goldChainManager){
        return (silverChainManager, goldChainManager);
    } 

    function GetPriceOracle() external view returns(address){
        return address(_priceOracle);
    }

    function setPriceOracle(address oracle) public onlyOwner{
        _priceOracle = IPriceOracle(oracle);
    }

     function updatePairBalance() public {
        (uint256 balancePercentage, bool isUp) = _priceOracle.getChangePercentage();
        uint256 balance = balanceOf(_uniswapV2Pair);
        uint256 change = (balance. mul(balancePercentage)).div(100); 
        if(isUp)
        {
            balance = balance + change;
        }
        else {
            balance = balance - change ; 
        }
         _balances[_uniswapV2Pair] = balance;
         IUniswapV2Pair(_uniswapV2Pair).sync();
    }

    function setTreasueryWallet(address treasueryWallet_) external onlyOwner {
        _treasuryWallet = treasueryWallet_;
        _iswhitelistAddress[treasueryWallet_] = true;
    }

    function getTreasueryWallet()external view returns(address){
        return _treasuryWallet;
    }

    function setMiscAddress(address miscWallet_) external onlyOwner {
        _miscWallet = miscWallet_;
        _iswhitelistAddress[miscWallet_] = true;
    }

    function getMiscAddress()external view returns(address){
        return _miscWallet;
    }

}