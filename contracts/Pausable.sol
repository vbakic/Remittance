pragma solidity 0.4.24;

import "./Mortal.sol";

contract Pausable is Mortal {

    bool isRunning;

    event LogPauseContract(address indexed accountAddress);
    event LogResumeContract(address indexed accountAddress);

    modifier onlyIfRunning {
        require(isRunning, "Error: contract paused");
        _;
    }

    constructor() public {
        isRunning = true;
    }

    function getState() public view returns (bool) {
        return isRunning;
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