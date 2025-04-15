// SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Timer is Ownable {

    modifier onlyOperator(){
        require(msg.sender == Operator, NOT_AUTHORIZED);
        _;
    }
    string constant NOT_AUTHORIZED = "TIMER1";
    uint256 private Days; 
    uint256 private ResetTime; 
    address private Operator;


    constructor(address operator){
        Operator = operator;
        ResetTime = block.timestamp;
    }


    function getOperator() public view returns(address _operator){
        return Operator;
    }

    function setOperator(address _operator) public onlyOwner{
        Operator = _operator;
    }

    function getTime() public view returns(uint256){
        return block.timestamp - ResetTime;
    }

    function getDay() public view returns(uint256){
        return Days;
    }

    function ResetTimer() public onlyOperator{
        Days++;
        ResetTime = block.timestamp;
    }

}