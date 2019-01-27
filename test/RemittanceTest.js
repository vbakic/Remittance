const Remittance = artifacts.require("Remittance");

web3.eth.getTransactionReceiptMined = require("../utils/getTransactionReceiptMined.js");
const expectedException = require("../utils/expectedExceptionPromise.js");
const helper = require("../utils/truffleTestHelper"); //to be able to jump blocks into the future

const [Running, Paused, Killed, invalidState] = [0, 1, 2, 10];
const revertPeriod = 5;
const claimBackPeriod = 10;
const amountWei = 100;

function checkIfSuccessfulTransaction(tx, caller, expectedEventName) {
    assert.strictEqual(tx.logs.length, 1, "Only one event");
    assert.strictEqual(tx.logs[0].args.caller, caller, "Wrong caller");
    assert.strictEqual(tx.logs[0].event, expectedEventName, "Wrong event");
    return assert.equal(tx.receipt.status, 1);
}

function checkChangeOwnerEventArgs(tx, newOwner) {
    return assert.strictEqual(tx.logs[0].args.newOwner, newOwner, "Wrong newOwner");
}

function checkCorrectAmount(tx) {
    return assert.strictEqual(parseInt(tx.logs[0].args.amount.toNumber()), amountWei, "Wrong amount");
}

function checkCorrectRemitterAddress(tx, remitter) {
    return assert.strictEqual(tx.logs[0].args.remitter, remitter, "Wrong remitter");
}

contract("Remittance", accounts => {

    const [firstAccount, secondAccount, thirdAccount] = accounts;

    it("should reject deploying contract as killed", async () => {
        await expectedException(() => {
            return Remittance.new(Killed, revertPeriod, claimBackPeriod, { from: firstAccount })
        });
    });

    describe("testing paused contract", function() {
        let RemittancePaused;
        beforeEach(async() => {
            RemittancePaused = await Remittance.new(Paused, revertPeriod, claimBackPeriod, { from: firstAccount });
        });

        it("test resume", async () => {
            let tx = await RemittancePaused.resumeContract({ from: firstAccount });
            checkIfSuccessfulTransaction(tx, firstAccount, "LogResumeContract");
            assert.equal(await RemittancePaused.getState(), 0);
        });
    
        it("test kill", async () => {
            let tx = await RemittancePaused.killContract({ from: firstAccount });
            checkIfSuccessfulTransaction(tx, firstAccount, "LogKillContract");
            assert.equal(await RemittancePaused.getState(), 2);
        });
    
        it("should reject resume from non-owner", async () => {
            await expectedException(async() => {
                await RemittancePaused.resumeContract({ from: secondAccount });
            });
        });
    
        it("should reject kill from non-owner", async () => {
            await expectedException(async() => {
                await RemittancePaused.killContract({ from: secondAccount });
            });
        });

        it("should reject deposit when paused", async () => {
            let password = "password123";
            hash = await RemittancePaused.calculateHash(password, secondAccount, { from: firstAccount })
            await expectedException(async() => {
                await RemittancePaused.depositEther(hash, secondAccount, { from: firstAccount, value: amountWei })
            });
        });

    });

    describe("testing running contract", function() {
        let RemittanceRunning;
        beforeEach(async() => {
            RemittanceRunning = await Remittance.new(Running, revertPeriod, claimBackPeriod, { from: firstAccount });
        });
    
        it("test getOwner", async () => {
            assert.equal(await RemittanceRunning.getOwner(), firstAccount);
        });
    
        it("test getState", async () => {
            assert.equal(await RemittanceRunning.getState(), 0);
        });
    
        it("test changing owner", async () => {
            let tx = await RemittanceRunning.changeOwner(secondAccount, { from: firstAccount });
            checkIfSuccessfulTransaction(tx, firstAccount, "LogChangeOwner");
            checkChangeOwnerEventArgs(tx, secondAccount);
            assert.equal(await RemittanceRunning.getOwner(), secondAccount);
        });
    
        it("test pause", async () => {
            let tx = await RemittanceRunning.pauseContract({ from: firstAccount });
            checkIfSuccessfulTransaction(tx, firstAccount, "LogPauseContract");
            assert.equal(await RemittanceRunning.getState(), 1);
        });    

        it("should reject direct transaction without value", async () => {
            await expectedException(async() => {
                await RemittanceRunning.sendTransaction({ from: firstAccount });
            });
        });
    
        it("should reject direct transaction with value", async() => {
            await expectedException(async() => {
                await RemittanceRunning.sendTransaction({ from: firstAccount, value: 10 });
            });
        });

        it("should reject change owner from non-owner", async () => {
            await expectedException(async() => {
                await RemittanceRunning.changeOwner(thirdAccount, { from: secondAccount });
            });
        });
    
        it("should reject pause from non-owner", async () => {
            await expectedException(async() => {
                await RemittanceRunning.pauseContract({ from: secondAccount });
            });
        });
    
        it("should reject kill if not paused", async () => {
            await expectedException(async() => {
                await RemittanceRunning.killContract({ from: firstAccount });
            });
        });

        it("test updating periods", async () => {
            let newRevertPeriod = 10;
            let newClaimBackPeriod = 30;
            let tx = await RemittanceRunning.changeClaimBackPeriods(newRevertPeriod, newClaimBackPeriod, { from: firstAccount });
            checkIfSuccessfulTransaction(tx, firstAccount, "LogChangeClaimBackPeriods");
            assert.equal(await RemittanceRunning.revertPeriod(), newRevertPeriod);
            assert.equal(await RemittanceRunning.claimBackPeriod(), newClaimBackPeriod);
        });

        it("should reject updating to invalid periods", async () => {
            let newRevertPeriod = 30;
            let newClaimBackPeriod = 10; //invalid, claim back period has to be longer than revert period
            await expectedException(async() => {
                await RemittanceRunning.changeClaimBackPeriods(newRevertPeriod, newClaimBackPeriod, { from: firstAccount });
            });
        });

        it("should pass revert / claim back", async () => {
            let currentBlockNumber = await web3.eth.getBlock('latest').number;
            let revertUntil = currentBlockNumber + 2;
            let claimBackAfter = currentBlockNumber - 2;
            let result = await RemittanceRunning.isEligibleForClaimBack(revertUntil, claimBackAfter, { from: firstAccount });
            assert.equal(result, true);
        });

        it("should fail revert / claim back", async () => {
            let currentBlockNumber = await web3.eth.getBlock('latest').number;
            let revertUntil = currentBlockNumber - 2;
            let claimBackAfter = currentBlockNumber + 2;
            let result = await RemittanceRunning.isEligibleForClaimBack(revertUntil, claimBackAfter, { from: firstAccount });
            assert.equal(result, false);
        });

        it("should reject deposit to the same address", async () => {
            let password = "password123";
            hash = await RemittanceRunning.calculateHash(password, firstAccount, { from: firstAccount })
            await expectedException(async() => {
                await RemittanceRunning.depositEther(hash, firstAccount, { from: firstAccount, value: amountWei })
            });
        });

    });

    describe("deposit/claimback/withdraw tests, each starts with deposit", function() {
        
        let RemittanceRunning, hash;
        let password = "password123"
        beforeEach(async() => {
            RemittanceRunning = await Remittance.new(Running, revertPeriod, claimBackPeriod, { from: firstAccount });
            hash = await RemittanceRunning.calculateHash(password, secondAccount, { from: firstAccount })
            let tx = await RemittanceRunning.depositEther(hash, secondAccount, { from: firstAccount, value: amountWei })
            checkIfSuccessfulTransaction(tx, firstAccount, "LogDepositEther");
            checkCorrectAmount(tx);
            checkCorrectRemitterAddress(tx, secondAccount);
            let deposits = await RemittanceRunning.deposits(hash);
            assert.equal(deposits[0].toNumber(), amountWei);
            assert.equal(await web3.eth.getBalance(RemittanceRunning.address).toNumber(), amountWei);
        });

        it("test two consecutive deposits", async () => {
            let password2 = "pepper"
            let hash2 = await RemittanceRunning.calculateHash(password2, secondAccount, { from: firstAccount })
            let tx2 = await RemittanceRunning.depositEther(hash2, secondAccount, { from: firstAccount, value: amountWei })
            checkIfSuccessfulTransaction(tx2, firstAccount, "LogDepositEther");
            checkCorrectAmount(tx2);
            checkCorrectRemitterAddress(tx2, secondAccount);
            let deposits2 = await RemittanceRunning.deposits(hash2);
            assert.equal(deposits2[0].toNumber(), amountWei);
            assert.equal(await web3.eth.getBalance(RemittanceRunning.address).toNumber(), amountWei * 2 );
        });

        it("should reject two deposits with same password", async () => {
            await expectedException(async() => {
                await RemittanceRunning.depositEther(hash, secondAccount, { from: firstAccount, value: amountWei })
            });
        });

        it("withdraw test", async () => {
            let tx = await RemittanceRunning.withdrawEther(password, { from: secondAccount });
            checkIfSuccessfulTransaction(tx, secondAccount, "LogWithdrawEther");
            checkCorrectAmount(tx);
        });

        it("should reject withdraw of inexisting funds", async () => {
            let tx = await RemittanceRunning.withdrawEther(password, { from: secondAccount });
            checkIfSuccessfulTransaction(tx, secondAccount, "LogWithdrawEther");
            checkCorrectAmount(tx);
            await expectedException(async() => {
                await RemittanceRunning.withdrawEther(hash, { from: secondAccount })
            });
        });

        it("should reject withdraw with incorrect hashed password", async () => {
            let incorrecthash = "0x4b66109c1db4cbfb87c5371a851adf15b8935db95b1c141a8f73e75bbf183f1e";
            await expectedException(async() => {
                await RemittanceRunning.withdrawEther(incorrecthash, { from: secondAccount })
            });
        });

        it("should reject withdraw when paused", async () => {
            let tx = await RemittanceRunning.pauseContract({ from: firstAccount });
            checkIfSuccessfulTransaction(tx, firstAccount, "LogPauseContract");
            assert.equal(await RemittanceRunning.getState(), 1);
            await expectedException(async() => {
                await RemittanceRunning.withdrawEther(hash, { from: secondAccount })
            });
        });

        it("should reject withdraw when killed", async () => {
            let tx = await RemittanceRunning.pauseContract({ from: firstAccount });
            checkIfSuccessfulTransaction(tx, firstAccount, "LogPauseContract");
            assert.equal(await RemittanceRunning.getState(), 1);
            let tx2 = await RemittanceRunning.killContract({ from: firstAccount });
            checkIfSuccessfulTransaction(tx2, firstAccount, "LogKillContract");
            assert.equal(await RemittanceRunning.getState(), 2);
            await expectedException(async() => {
                await RemittanceRunning.withdrawEther(hash, { from: secondAccount })
            });
        });

        it("claim back test", async () => {
            let tx = await RemittanceRunning.claimBackEther(hash, { from: firstAccount });
            checkIfSuccessfulTransaction(tx, firstAccount, "LogClaimBackEther");
            checkCorrectAmount(tx);
        });

        it("should fail two consecutive claim backs", async () => {
            let tx = await RemittanceRunning.claimBackEther(hash, { from: firstAccount });
            checkIfSuccessfulTransaction(tx, firstAccount, "LogClaimBackEther");
            checkCorrectAmount(tx);
            await expectedException(async() => {
                await RemittanceRunning.claimBackEther(hash, { from: firstAccount });
            });
        });

        it("claim back test #2", async () => {
            for(var i=0; i < claimBackPeriod; i++) {
                await helper.advanceBlock();
            }
            let tx = await RemittanceRunning.claimBackEther(hash, { from: firstAccount });
            checkIfSuccessfulTransaction(tx, firstAccount, "LogClaimBackEther");
            checkCorrectAmount(tx);
        });

        it("should reject claim back because revert period expired", async () => {
            for(var i=0; i < revertPeriod; i++) {
                await helper.advanceBlock();
            }
            await expectedException(async() => {
                await RemittanceRunning.claimBackEther(hash, { from: firstAccount });
            });
        });
    
    });

    describe("testing killed contract", function() {
        let RemittanceKilled;
        beforeEach( async () => {
            //setting initial state to paused because it can't be started as killed
            RemittanceKilled = await Remittance.new(Paused, revertPeriod, claimBackPeriod, { from: firstAccount })
            await RemittanceKilled.killContract({from: firstAccount}); //killing the contract
        });
    
        it("should reject resume if killed", async () => {
            await expectedException(async() => {
                await RemittanceKilled.resumeContract({ from: firstAccount });
            });
        });
    
        it("should reject pause if killed", async () => {
            await expectedException(async() => {
                await RemittanceKilled.pauseContract({ from: firstAccount });
            });
        });

        it("should reject deposit when killed", async () => {
            let password = "password123";
            hash = await RemittanceKilled.calculateHash(password, secondAccount, { from: firstAccount })
            await expectedException(async() => {
                await RemittanceKilled.depositEther(hash, secondAccount, { from: firstAccount, value: amountWei })
            });
        });
    
    });

    describe("testing constructor parameters", function() {

        it("should reject if revert/claimback reversed", async () => {
            await expectedException(async() => {
                await Remittance.new(Paused, claimBackPeriod, revertPeriod, { from: firstAccount })
            });
        });

        it("should reject if invalid state provided", async () => {
            await expectedException(async() => {
                await Remittance.new(invalidState, revertPeriod, claimBackPeriod, { from: firstAccount })
            });
        });        
    
    });

});


