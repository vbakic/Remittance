pragma solidity 0.4.24;

import "./Mortal.sol";

contract Ownable is Mortal {

    event LogChangeOwner(address indexed newOwner);

    function changeOwner(address newOwner) public onlyOwner onlyIfAlive returns (bool) {
        require(newOwner != owner, "Error: already that owner");
        emit LogChangeOwner(newOwner);
        owner = newOwner;
        return true;
    }

}