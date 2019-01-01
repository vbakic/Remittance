pragma solidity 0.4.24;

import "./Ownable.sol";

contract Pausable is Ownable {

    bool public isRunning;

    event LogPauseContract(address indexed accountAddress);
    event LogResumeContract(address indexed accountAddress);

    modifier onlyIfRunning {
        require(isRunning, "Error: contract paused");
        _;
    }

    constructor() public {
        isRunning = true;
    }

    function pauseContract() public onlyIfRunning onlyOwner returns(bool) {
        emit LogPauseContract(msg.sender);
        isRunning = false;
        return true;
    }

    function resumeContract() public onlyOwner returns(bool) {
        require(isRunning == false, "Error: contract already running");
        emit LogResumeContract(msg.sender);
        isRunning = true;
        return true;
    }
}