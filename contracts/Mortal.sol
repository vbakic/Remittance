pragma solidity 0.4.24;

import "./Owned.sol";

contract Mortal is Owned {

    bool isAlive;

    event LogKillContract(address killer);

    constructor() public {
        isAlive = true;
    }

    modifier onlyIfAlive {
        require(isAlive, "Error: contract killed");
        _;
    }

    function checkIsAlive() public view returns (bool) {
        return isAlive;
    }

    function killContract() public onlyOwner onlyIfAlive returns (bool success) {
        emit LogKillContract(msg.sender);
        isAlive = false;
        return true;
    }
    
}