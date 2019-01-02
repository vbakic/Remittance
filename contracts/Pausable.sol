pragma solidity 0.4.24;

import "./Ownable.sol";

contract Pausable is Ownable {

    bool private isRunning;

    event LogPauseContract(address indexed accountAddress);
    event LogResumeContract(address indexed accountAddress);

    modifier onlyIfRunning {
        require(isRunning, "Error: contract paused");
        _;
    }

    constructor() public {
        isRunning = true;
    }

    function getState() public view onlyOwner returns (bool) {
        return isRunning;
    }

    function setState(bool newState) public onlyOwner returns (bool) {
        isRunning = newState;
        return true;
    }
}