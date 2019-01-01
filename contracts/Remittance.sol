pragma solidity 0.4.24;

import "./SafeMath.sol";
import "./Pausable.sol";

contract Remittance is Pausable {

    using SafeMath for uint;
    
    struct Account {
        uint balance;
        bytes32 hash;
        uint timestamp;
        address originalSender;
    }

    mapping (address => Account) public accounts;

    event LogDepositEther(address indexed sender, address indexed receiver, uint amount, bytes32 password1, bytes32 password2);
    event LogWithdrawEther(address indexed accountAddress, bytes32 password1, bytes32 password2);
    event LogClaimBackEther(address indexed sender, address indexed receiver, uint timestamp);
    
    function depositEther(address receiver, bytes32 password1, bytes32 password2) public payable onlyIfRunning returns (bool success) {
        require(receiver != address(0), "Error: invalid address");
        require(receiver != msg.sender, "Error: deposit to own account not permited");
        require(accounts[receiver].balance == 0, "Error: deposit not possible until existing funds are withdrawn");
        emit LogDepositEther(msg.sender, receiver, msg.value, password1, password2);
        accounts[receiver].hash = keccak256(abi.encodePacked(password1, password2));
        accounts[receiver].balance = accounts[receiver].balance.add(msg.value);
        accounts[receiver].timestamp = now;
        accounts[receiver].originalSender = msg.sender;
        return true;
    }

    function claimBackEther(address claimBackFrom) public payable onlyIfRunning returns (bool success) {
        require(claimBackFrom != address(0), "Error: invalid address");
        require(msg.sender == accounts[claimBackFrom].originalSender, "Error: only original sender can claim back funds");
        require(now - accounts[claimBackFrom].timestamp < 30 minutes, "Error: claim back option expired");
        uint amount = accounts[claimBackFrom].balance;
        require(amount != 0, "Error: insufficient funds");
        emit LogClaimBackEther(msg.sender, claimBackFrom, now);
        accounts[claimBackFrom].balance = 0;
        msg.sender.transfer(amount);
        return true;
    }
    
    function withdrawEther(bytes32 password1, bytes32 password2) public payable onlyIfRunning returns (bool success) {
        require(accounts[msg.sender].balance != 0, "Error: insufficient funds");
        bytes32 hash = keccak256(abi.encodePacked(password1, password2));
        require(hash == accounts[msg.sender].hash, "Error: incorrect passwords");
        emit LogWithdrawEther(msg.sender, password1, password2);
        uint amount = accounts[msg.sender].balance;
        accounts[msg.sender].balance = 0;
        msg.sender.transfer(amount);
        return true;
    }

    function getAccountBalance() public view returns (uint) {
        return accounts[msg.sender].balance;
    }

    function killContract() public onlyOwner returns (bool success) {
        selfdestruct(owner);
        return true;
    }
    
}
