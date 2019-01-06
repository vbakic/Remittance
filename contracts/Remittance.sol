pragma solidity 0.4.24;

import "./SafeMath.sol";
import "./Pausable.sol";
import "./Transferrable.sol";

contract Remittance is Pausable, Transferrable {

    using SafeMath for uint;
    uint public revertPeriod;
    uint public claimBackPeriod;
    
    struct Deposit {
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

    function calculateHash(bytes32 plainPassword, address remitter) public view returns(bytes32 hashedPassword) {
        require(remitter != address(0), "Error: invalid address");
        return keccak256(abi.encodePacked(plainPassword, remitter, address(this)));
    }
    
    function depositEther(bytes32 hashedPassword, address remitter) public payable onlyIfRunning onlyIfAlive returns (bool success) {
        Deposit memory deposit = deposits[hashedPassword];
        uint balance = deposit.balance;
        require(msg.value != 0, "Error: no ether provided");
        require(remitter != msg.sender, "Error: deposit to own account not permited");
        //the line below should prevent using previous password for the same remitter, it would require that the storage block hasn't been used before
        require(deposit.revertUntil == 0 && deposit.originalSender == address(0), "Error: new password required");
        emit LogDepositEther(msg.sender, remitter, msg.value);
        deposit.balance = balance.add(msg.value);
        deposit.revertUntil = block.number.add(revertPeriod);
        deposit.claimBackAfter = block.number.add(claimBackPeriod);
        deposit.originalSender = msg.sender;
        deposits[hashedPassword] = deposit;
        return true;
    }

    function claimBackEther(bytes32 hashedPassword) public onlyIfRunning onlyIfAlive returns (bool success) {
        Deposit memory deposit = deposits[hashedPassword];
        require(msg.sender == deposit.originalSender, "Error: only original sender can claim back funds");
        uint balance = deposit.balance;
        require(balance != 0, "Error: insufficient funds");
        require(isEligibleForClaimBack(deposit.revertUntil, deposit.claimBackAfter), "Error: not eligible for claim back");
        emit LogClaimBackEther(msg.sender, balance);
        deposit.balance = 0;
        deposits[hashedPassword] = deposit;
        msg.sender.transfer(balance);
        return true;
    }
    
    function withdrawEther(bytes32 plainPassword) public returns (bool success) {
        //only remitter could create the hashedPassword, without passing its address
        bytes32 hashedPassword = calculateHash(plainPassword, msg.sender);
        uint balance = deposits[hashedPassword].balance;
        require(balance != 0, "Error: no ether available or already withdrawn");
        emit LogWithdrawEther(msg.sender, balance);
        deposits[hashedPassword].balance = 0;
        msg.sender.transfer(balance);
        return true;
    }


}
