pragma solidity 0.4.24;

contract BaseContract {

    address owner;

    constructor() public {
        owner = msg.sender;
    }

    modifier onlyOwner {
        require(msg.sender == owner, "Error: only owner is allowed to do that");
        _;
    }

    function getOwner() public view returns (address) {
        return owner;
    }

}