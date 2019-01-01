pragma solidity 0.4.24;

import "./SafeMath.sol";

contract Ownable {

    address public owner;

    event LogChangeOwner(address indexed newOwner, address indexed oldOwner);

    modifier onlyOwner {
        require(msg.sender == owner, "Error: only owner is allowed to do that");
        _;
    }

    constructor() public {
        owner = msg.sender;
    }

    function changeOwner(address newOwner) public onlyOwner returns (bool) {
        require(newOwner != owner, "Error: already that owner");
        emit LogChangeOwner(newOwner, msg.sender);
        owner = newOwner;
        return true;
    }

}

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

contract Remittance is Pausable {

    using SafeMath for uint;
    
    struct Account {
        uint balance;
        bytes32 hash;
        uint timestamp;
        address originalSender;
    }

    mapping (address => Account) public accounts;

    event LogDepositEther(address indexed sender, address indexed receiver, uint amount, string password1, string password2);
    event LogWithdrawEther(address indexed accountAddress, string password1, string password2);
    event LogClaimBackEther(address indexed sender, address indexed receiver, uint timestamp);
    
    function depositEther(address receiver, string password1, string password2) public payable onlyIfRunning returns (bool success) {
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
    
    function withdrawEther(string password1, string password2) public payable onlyIfRunning returns (bool success) {
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
