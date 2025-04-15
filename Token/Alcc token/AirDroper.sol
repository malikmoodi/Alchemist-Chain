// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "./contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "./contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./contracts-upgradeable/proxy/utils/Initializable.sol";
import "./contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./IERC20.sol";
import "./SafeMath.sol";
import "./IAlchemicToken.sol";

contract AirDroper is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    using SafeMath for uint256;

    address private alccV2;
    address private alccV1;
    address private operator;

    address[] private usersArr;
    mapping(address => uint256) private userAirdropAmount;
    mapping(address => uint256) private sentAmount;

    string constant NOT_AUTHORIZED = "AL-AIR-1";
    string constant SENDING_HIGHER = "AL-AIR-2";
    string constant CANNOT_SEND_MORE = "AL-AIR-3";
    string constant ARRAYS_ERROR = "AL-AIR-4";
    string constant OVERFLOW_PAGE = "AL-AIR-5";
    string constant NOT_ELIGIBLE = "AL-AIR-6";
    string constant CHECK_ERROR = "AL-AIR-7";
    string constant AIRDROP_DONE = "AL-AIR-8";

    function initialize(address _alccV1, address _alccV2, address _operator) initializer public {
        __Ownable_init();
        __UUPSUpgradeable_init();
        operator = _operator;
        alccV1 = _alccV1;
        alccV2 = _alccV2;
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyOwner
        override
    {}

   ////////////////////////////////////////////////

    function check() private view returns(bool){
        uint256 addArrLen = usersArr.length;
        /// we can use alccV1Balance instead of userAirdropAmount[usersArr[i]]
        for(uint i; i < addArrLen; i++){
            uint256 alccV1Balance = IERC20(alccV1).balanceOf(usersArr[i]); 
            uint256 alccV2Balance = IERC20(alccV2).balanceOf(usersArr[i]); 
            
            require(alccV2Balance <= alccV1Balance, AIRDROP_DONE);
            require(alccV1Balance >= userAirdropAmount[usersArr[i]], SENDING_HIGHER);
            require(alccV1Balance >= userAirdropAmount[usersArr[i]].add(sentAmount[usersArr[i]]), CANNOT_SEND_MORE);
        }

        return true;
    }
    // need to white list this contract in ALCCV2
    function startAirdrop() public onlyOwner{ 

        require(check(), CHECK_ERROR);

        uint256 addArrLen = usersArr.length;

        for(uint i; i < addArrLen; i++){
            IAlchemicToken(alccV2).distributeReward(userAirdropAmount[usersArr[i]]);
            sentAmount[usersArr[i]] += userAirdropAmount[usersArr[i]];
            IERC20(alccV2).transfer(usersArr[i], userAirdropAmount[usersArr[i]]);
        }
    }

    function addUsersData(address[] memory _usersArr, uint256[] memory _amountArr) public{
        require(msg.sender == operator, NOT_AUTHORIZED);

        uint256 addArrLen = _usersArr.length;
        uint256 amountArrLen = _amountArr.length;
        require(amountArrLen == addArrLen, ARRAYS_ERROR);
        
        for(uint i; i < addArrLen; i++){
            uint256 alccV1Balance = IERC20(alccV1).balanceOf(_usersArr[i]); 
            require(alccV1Balance >= _amountArr[i], SENDING_HIGHER);
            userAirdropAmount[_usersArr[i]] = _amountArr[i];
            usersArr.push(_usersArr[i]); ///new 
        }

        // usersArr = new address[](addArrLen);
        // usersArr = _usersArr;
    }

    // function getAirdropedWithData(uint256 _amount) public{
    //     require(userAirdropAmount[msg.sender] > 0, NOT_ELIGIBLE);
    //     uint256 alccV1Balance = IERC20(alccV1).balanceOf(msg.sender); 
    //     require(alccV1Balance >= _amount, ASKING_HIGHER);
    //     require(alccV1Balance >= _amount.add(sentAmount[msg.sender]), ASKING_AGAIN);

    //     IAlchemicToken(alccV2).distributeReward(_amount);
    //     sentAmount[msg.sender] += _amount;
    //     IERC20(alccV2).transfer(msg.sender, _amount);
    // }
    function getUsersArr(uint256 page , uint256 size) public view returns(address[] memory){
        uint256 addArrLen = usersArr.length;
        
        uint256 ToSkip = page*size;  //to skip
        uint256 count = 0  ; 
        uint256 EndAt = addArrLen > ToSkip + size ? ToSkip + size : addArrLen;
        require(ToSkip < addArrLen, OVERFLOW_PAGE);
        require(EndAt>ToSkip, OVERFLOW_PAGE);
        address[] memory _usersArr = new address[](EndAt-ToSkip);
        for (uint256 i = ToSkip ; i < EndAt; i++) {
            _usersArr[count] = usersArr[i];
            count++;
        }
        return _usersArr;
    }

    function getSentAmount(address _user) public view returns(uint256 _sentAmount) {
        return sentAmount[_user];
    }

    function getUserAirdropAmount(address _user) public view returns(uint256 _airdropAmount) {
        return userAirdropAmount[_user];
    }

    function setOperator(address _operator) public onlyOwner{
        operator = _operator;
    }

    function getOperator() public view returns(address){
        return operator;
    }

    function setALCCV1(address _alccV1) public onlyOwner{
        alccV1 = _alccV1;   
    }

    function getALCCV1() public view returns (address _alccV1){
        return alccV1;
    }

    function setALCCV2(address _alccV2) public onlyOwner{
        alccV2 = _alccV2;   
    }

    function getALCCV2() public view returns (address _alccV2){
        return alccV2;
    }
   ///////////////////////////////
    
    function withdrawToken(address _token, address _beneficiary, uint256 _amount) public onlyOwner{
        IERC20(_token).transfer(_beneficiary, _amount);
    }

    function withdrawCurrency(address _destionation, uint256 _amount) public onlyOwner {
        payable(_destionation).transfer(_amount);
    }

    function getCurrencyBalance() public view returns(uint256){
        return (address(this)).balance;
    }

    function getTokenBalance(address _token) public view returns(uint256){
        return IERC20(_token).balanceOf(address(this));
    }

    receive() external payable {}
}