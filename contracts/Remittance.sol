pragma solidity 0.4.24;

import "./SafeMath.sol";
import "./Pausable.sol";
import "./Transferrable.sol";

contract Remittance is Pausable, Transferrable {

    using SafeMath for uint;
    uint public revertPeriod;
    uint public claimBackPeriod;
    
    struct Deposit {
        address remitter;
        uint balance;
        uint revertUntil;
        uint claimBackAfter;
        address originalSender;
    }

    mapping (bytes32 => Deposit) public deposits;

    event LogDepositEther(address indexed sender, address indexed remitter, uint amount);
    event LogWithdrawEther(address indexed remitter, uint amount);
    event LogClaimBackEther(address indexed sender, uint amount);

    constructor() public {
        revertPeriod = 10;
        claimBackPeriod = 100;
    }

    function changeClaimBackPeriods(uint newRevertPeriod, uint newclaimBackPeriod) 
            public onlyOwner onlyIfAlive returns(bool success) {
        revertPeriod = newRevertPeriod;
        claimBackPeriod = newclaimBackPeriod;
        return true;
    }

    function isEligibleForClaimBack(uint revertUntil, uint claimBackAfter) public view returns(bool) {
        if( block.number <= revertUntil || block.number >= claimBackAfter ) {
            return true;
        }
        return false;
    }

    function calculateHash(bytes32 password, address remitter) public pure returns(bytes32 hash) {
        require(remitter != address(0), "Error: invalid address");
        return keccak256(abi.encodePacked(password, remitter));
    }
    
    function depositEther(bytes32 hash, address remitter) public payable onlyIfRunning onlyIfAlive returns (bool success) {
        uint balance = deposits[hash].balance;
        require(msg.value != 0, "Error: no ether provided");
        require(remitter != msg.sender, "Error: deposit to own account not permited");
        require(deposits[hash].remitter != remitter, "Error: new password required");
        emit LogDepositEther(msg.sender, remitter, msg.value);
        deposits[hash].balance = balance.add(msg.value);
        deposits[hash].remitter = remitter;
        deposits[hash].revertUntil = block.number.add(revertPeriod);
        deposits[hash].claimBackAfter = block.number.add(claimBackPeriod);
        deposits[hash].originalSender = msg.sender;
        return true;
    }

    function claimBackEther(bytes32 hash) public onlyIfRunning onlyIfAlive returns (bool success) {
        require(msg.sender == deposits[hash].originalSender, "Error: only original sender can claim back funds");
        uint balance = deposits[hash].balance;
        require(balance != 0, "Error: insufficient funds");
        require(isEligibleForClaimBack(deposits[hash].revertUntil, deposits[hash].claimBackAfter), "Error: not eligible for claim back");
        emit LogClaimBackEther(msg.sender, balance);
        deposits[hash].balance = 0;
        msg.sender.transfer(balance);
        return true;
    }
    
    function withdrawEther(bytes32 password) public returns (bool success) {
        bytes32 hash = calculateHash(password, msg.sender); //only remitter could create the hash, without passing its address
        require(msg.sender == deposits[hash].remitter, "Error: requested funds are not yours");
        uint balance = deposits[hash].balance;
        require(balance != 0, "Error: no ether available or already withdrawn");
        emit LogWithdrawEther(msg.sender, balance);
        deposits[hash].balance = 0;
        msg.sender.transfer(balance);
        return true;
    }


}
