pragma solidity 0.4.24;

import "./Pausable.sol";

contract Mortal is Pausable {

    bool private isAlive; //private instead of internal because its unused in child contract

    constructor() public {
        isAlive = true;
    }

    modifier onlyIfAlive {
        require(isAlive, "Error: contract killed");
        _;
    }

    event LogKillContract(address killer);

    function checkIsAlive() public view returns (bool) {
        return isAlive;
    }

    function killContract() public onlyOwner onlyIfAlive returns (bool success) {
        emit LogKillContract(msg.sender);
        isRunning = false; //pause contract first
        isAlive = false;
        return true;
    }

    function changeOwner(address newOwner) public onlyOwner onlyIfAlive returns (bool) {
        require(newOwner != owner, "Error: already that owner");
        emit LogChangeOwner(newOwner);
        owner = newOwner;
        return true;
    }

    function pauseContract() public onlyIfRunning onlyOwner onlyIfAlive returns(bool) {
        emit LogPauseContract(msg.sender);
        isRunning = false;
        return true;
    }

    function resumeContract() public onlyOwner onlyIfAlive returns(bool) {
        require(isRunning == false, "Error: contract already running");
        emit LogResumeContract(msg.sender);
        isRunning = true;
        return true;
    }

    
}