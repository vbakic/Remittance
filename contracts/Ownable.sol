pragma solidity 0.4.24;

contract Ownable {

    address owner;

    event LogChangeOwner(address indexed newOwner);

    modifier onlyOwner {
        require(msg.sender == owner, "Error: only owner is allowed to do that");
        _;
    }

    constructor() public {
        owner = msg.sender;
    }

    function getOwner() public view returns(address) {
        return owner;
    }

}