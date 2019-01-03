pragma solidity 0.4.24;

import "./SafeMath.sol";
import "./Pausable.sol";
import "./Ownable.sol";

contract Remittance is Pausable, Ownable {

    using SafeMath for uint;
    
    struct Deposit {
        address remitter;
        bytes32 receiver;
        uint balance;
        uint blockNumber;
        address originalSender;
    }

    mapping (bytes32 => Deposit) public deposits;

    event LogDepositEther(address indexed remitter, bytes32 indexed receiver, uint amount);
    event LogWithdrawEther(address indexed remitter, bytes32 indexed receiver, uint amount);
    event LogClaimBackEther(address indexed sender, uint amount);

    function calculateHash(bytes32 password1, bytes32 password2, address remitter, bytes32 receiver) public pure returns(bytes32 hash) {
        require(remitter != address(0), "Error: invalid address");
        return keccak256(abi.encodePacked(password1, password2, remitter, receiver));
    }
    
    function depositEther(bytes32 hash, address remitter, bytes32 receiver) public payable onlyIfRunning onlyIfAlive returns (bool success) {
        uint balance = deposits[hash].balance;
        require(msg.value != 0, "Error: no ether provided");
        require(remitter != msg.sender, "Error: deposit to own account not permited");
        emit LogDepositEther(remitter, receiver, msg.value);
        deposits[hash].balance = balance.add(msg.value);
        deposits[hash].remitter = remitter;
        deposits[hash].receiver = receiver;
        deposits[hash].blockNumber = block.number;
        deposits[hash].originalSender = msg.sender;
        return true;
    }

    function claimBackEther(bytes32 hash) public onlyIfRunning onlyIfAlive returns (bool success) {
        require(msg.sender == deposits[hash].originalSender, "Error: only original sender can claim back funds");
        require(block.number - deposits[hash].blockNumber < 30, "Error: claim back option expired");
        uint balance = deposits[hash].balance;        
        require(balance != 0, "Error: insufficient funds");
        emit LogClaimBackEther(msg.sender, balance);
        deposits[hash].balance = 0;
        msg.sender.transfer(balance);
        return true;
    }
    
    function withdrawEther(bytes32 password1, bytes32 password2, address remitter, bytes32 receiver) public returns (bool success) {
        bytes32 hash = calculateHash(password1, password2, remitter, receiver);
        require(msg.sender == deposits[hash].remitter, "Error: requested funds are not yours");
        uint balance = deposits[hash].balance;
        require(balance != 0, "Error: no ether available or already withdrawn");
        emit LogWithdrawEther(msg.sender, deposits[hash].receiver, balance);
        deposits[hash].balance = 0;
        msg.sender.transfer(balance);
        return true;
    }


}
