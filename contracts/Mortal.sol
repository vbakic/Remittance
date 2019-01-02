pragma solidity 0.4.24;

import "./Pausable.sol";

contract Mortal is Pausable {

    bool private isAlive;

    constructor() public {
        isAlive = true;
    }

    modifier onlyIfAlive {
        require(isAlive, "Error: contract killed");
        _;
    }

    event LogKillContract(address killer);

    function checkIsAlive() public view onlyOwner returns (bool) {
        return isAlive;
    }

    function killContract() public onlyOwner onlyIfAlive returns (bool success) {
        emit LogKillContract(msg.sender);
        setState(false); //pause contract first
        isAlive = false;
        return true;
    }

    function changeOwner(address newOwner) public onlyOwner onlyIfAlive returns (bool) {
        setOwner(newOwner);
        return true;
    }

    function pauseContract() public onlyIfRunning onlyOwner onlyIfAlive returns(bool) {
        emit LogPauseContract(msg.sender);
        setState(false);
        return true;
    }

    function resumeContract() public onlyOwner onlyIfAlive returns(bool) {
        require(getState() == false, "Error: contract already running");
        emit LogResumeContract(msg.sender);
        setState(true);
        return true;
    }

    
}