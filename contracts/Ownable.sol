pragma solidity 0.4.24;

contract Ownable {

    address private owner;

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

    function setOwner(address newOwner) public onlyOwner returns (bool) {
        require(newOwner != owner, "Error: already that owner");
        emit LogChangeOwner(newOwner);
        owner = newOwner;
        return true;
    }

}