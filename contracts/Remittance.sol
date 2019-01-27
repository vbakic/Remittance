pragma solidity 0.4.24;

import "./SafeMath.sol";
import "./Pausable.sol";

contract Remittance is Pausable {

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

    event LogDepositEther(address indexed caller, address indexed remitter, uint amount);
    event LogWithdrawEther(address indexed caller, uint amount);
    event LogClaimBackEther(address indexed caller, uint amount);
    event LogChangeClaimBackPeriods(address indexed caller, uint newRevertPeriod, uint newclaimBackPeriod);

    constructor(uint8 initialState, uint defaultRevertPeriod, uint defaultClaimBackPeriod) public Pausable(initialState) {
        changeClaimBackPeriods(defaultRevertPeriod, defaultClaimBackPeriod);
    }

    function changeClaimBackPeriods(uint newRevertPeriod, uint newclaimBackPeriod) 
            public onlyOwner onlyIfAlive returns(bool success) {
        require(newRevertPeriod != 0, "Error: RevertPeriod not provided / cannot be zero");
        require(newclaimBackPeriod != 0, "Error: ClaimBackPeriod not provided / cannot be zero");
        require(newclaimBackPeriod > newRevertPeriod, "Error: ClaimBackPeriod needs to longer than RevertPeriod");
        emit LogChangeClaimBackPeriods(msg.sender, newRevertPeriod, newclaimBackPeriod);
        revertPeriod = newRevertPeriod;
        claimBackPeriod = newclaimBackPeriod;
        return true;
    }

    function isEligibleForClaimBack(uint revertUntil, uint claimBackAfter) public view onlyIfAlive returns (bool) {
        return (block.number <= revertUntil || block.number >= claimBackAfter);
    }

    function calculateHash(bytes32 plainPassword, address remitter) public view returns(bytes32 hashedPassword) {
        require(remitter != address(0), "Error: invalid address");
        return keccak256(abi.encodePacked(plainPassword, remitter, address(this)));
    }
    
    function depositEther(bytes32 hashedPassword, address remitter) public payable onlyIfRunning returns (bool success) {
        Deposit memory deposit = deposits[hashedPassword];
        //the line below should prevent using previous password for the same remitter, it would require that the storage block hasn't been used before
        require(deposit.originalSender == address(0), "Error: new password required");
        uint balance = deposit.balance;
        require(msg.value != 0, "Error: no ether provided");
        require(remitter != msg.sender, "Error: deposit to own account not permited");
        emit LogDepositEther(msg.sender, remitter, msg.value);
        deposit.balance = balance.add(msg.value);
        deposit.revertUntil = block.number.add(revertPeriod);
        deposit.claimBackAfter = block.number.add(claimBackPeriod);
        deposit.originalSender = msg.sender;
        deposits[hashedPassword] = deposit; //in this case the entire struct is updated 
        return true;
    }

    function claimBackEther(bytes32 hashedPassword) public onlyIfRunning returns (bool success) {
        Deposit memory deposit = deposits[hashedPassword];
        require(msg.sender == deposit.originalSender, "Error: only original sender can claim back funds");
        uint balance = deposit.balance;
        require(balance != 0, "Error: insufficient funds");
        require(isEligibleForClaimBack(deposit.revertUntil, deposit.claimBackAfter), "Error: not eligible for claim back");
        emit LogClaimBackEther(msg.sender, balance);
        deposits[hashedPassword].balance = 0;
        deposits[hashedPassword].revertUntil = 0;
        deposits[hashedPassword].claimBackAfter = 0;
        msg.sender.transfer(balance);
        return true;
    }
    
    function withdrawEther(bytes32 plainPassword) public onlyIfRunning returns (bool success) {
        //only remitter could create the hashedPassword, without passing its address
        bytes32 hashedPassword = calculateHash(plainPassword, msg.sender);
        uint balance = deposits[hashedPassword].balance;
        require(balance != 0, "Error: no ether available or already withdrawn");
        emit LogWithdrawEther(msg.sender, balance);
        deposits[hashedPassword].balance = 0;
        deposits[hashedPassword].revertUntil = 0;
        deposits[hashedPassword].claimBackAfter = 0;
        msg.sender.transfer(balance);
        return true;
    }


}
