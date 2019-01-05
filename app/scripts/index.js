// Import libraries we need.
import { default as Web3 } from 'web3'
import { default as contract } from 'truffle-contract'

// Import our contract artifacts and turn them into usable abstractions.
import ContractArtifact from '../../build/contracts/Remittance.json'
const Contract = contract(ContractArtifact)
const Promise = require("bluebird");
const assert = require('assert-plus');

let accounts
let sender
let remitter
let instance
let owner

window.addEventListener('load', function () {
  window.web3 = new Web3(new Web3.providers.HttpProvider('http://127.0.0.1:8545'))
  web3.eth.getTransactionReceiptMined = require("../../utils/getTransactionReceiptMined.js");
  // Promisify all functions of web3.eth and web3.version
  Promise.promisifyAll(web3.eth, { suffix: "Promise" });
  Promise.promisifyAll(web3.version, { suffix: "Promise" });
  App.start()
  window.App = App
  jQuery("#sender, #remitter").change(() => {
    App.update();
  })
})

const App = {

  update: function() {
      console.log('update called!')
      sender = accounts[jQuery("#sender").val()]
      remitter = accounts[jQuery("#remitter").val()]
      this.refreshBalances()
  },

  start: async function () {
    const self = this

    // Bootstrap the Contract abstraction for Use.
    Contract.setProvider(web3.currentProvider)

    instance = await Contract.deployed()
    accounts = await web3.eth.getAccountsPromise()

    if (accounts.length < 5){
      throw new Error("No available accounts!");
    }
    else {
      sender = accounts[0]
      remitter = accounts[1]
      self.refreshBalances()
    }

  },

  followUpTransaction: async function(txHash) {
    console.log("Your transaction is on the way, waiting to be mined!", txHash);
    let receipt = await web3.eth.getTransactionReceiptMined(txHash);
    assert.strictEqual(parseInt(receipt.status), 1);
    console.log("Your transaction executed successfully!");
    return true;
  },

  killContract: async function () {
    let contractState = await instance.getState({from: owner})
    if(!contractState) { //only if paused
      let txHash = await instance.killContract.sendTransaction({from: owner})
      let success = await this.followUpTransaction(txHash);
      if(success) {
        jQuery("#isAlive").html("No");
      }
    } else {
      jQuery("#killError").html("Error: Contract needs to be paused first").show().delay(5000).fadeOut()
    }
  },

  pauseContract: async function () {
    let txHash = await instance.pauseContract.sendTransaction({from: owner})
    let success = await this.followUpTransaction(txHash);
    if(success) {
      jQuery("#contractState").html("Paused");
    }
    return true;
  },

  resumeContract: async function () {
    let txHash = await instance.resumeContract.sendTransaction({from: owner})
    let success = await this.followUpTransaction(txHash);
    if(success) {
      jQuery("#contractState").html("Running");
    }
  },

  changeOwner: async function () {
    let index = jQuery("#ownerSelector").val()
    if(accounts[index] != owner) {
      let txHash = await instance.changeOwner.sendTransaction(accounts[index], {from: owner})
      let success = await this.followUpTransaction(txHash);
      if(success) {
        owner = accounts[index];
        this.refreshOwnerInfo()
      }
    } else {
      console.error("Already that owner")
    }
  },

  refreshOwnerInfo: async function () {
    owner = await instance.getOwner({from: sender})
    for (let [index, element] of accounts.entries()) {
      if(element == owner) {
        jQuery("#currentOwner").val(index)
      }
    }
  },

  refreshBalances: async function () {
    const self = this
    self.refreshOwnerInfo()
    self.refreshAccountBalances()
    self.updateContractState()
    self.updatePeriods()
    const balance = await web3.eth.getBalancePromise(instance.address)
    jQuery('#Contract').val(convertToEther(balance))
  },

  updateContractState: async function () {
    let contractState = await instance.getState({from: owner})
    if(contractState) {
      jQuery('#contractState').html("Running")
    } else {
      jQuery('#contractState').html("Paused")
    }
    let isAlive = await instance.checkIsAlive({from: owner})
    if(isAlive) {
      jQuery('#isAlive').html("Yes")
    } else {
      jQuery('#isAlive').html("No")
    }
  },

  updatePeriods: async function () {
    let revertPeriod = await instance.revertPeriod({from: owner});
    let claimBackPeriod = await instance.claimBackPeriod({from: owner});
    jQuery("#revertPeriod").val(revertPeriod);
    jQuery("#claimBackPeriod").val(claimBackPeriod);    
  },

  refreshAccountBalances: async function () {

    const senderBalance = await web3.eth.getBalancePromise(sender)
    const remitterBalance = await web3.eth.getBalancePromise(remitter)

    jQuery("#SenderBalance").val(convertToEther(senderBalance))
    jQuery("#RemitterBalance").val(convertToEther(remitterBalance))
    
  },

  depositEther: async function () {
      const self = this
      let password = jQuery("#depositPassword1").val() + jQuery("#depositPassword2").val()
      console.log(password)
      const amountWei = convertToWei(jQuery("#depositAmount").val())
      if(amountWei > 0) {
        let hash = await instance.calculateHash(password, remitter, { from: sender })
        console.log(hash)
        let txHash = await instance.depositEther.sendTransaction(hash, remitter, { from: sender, value: amountWei, gas: 180000 })
        let success = await this.followUpTransaction(txHash);
        if(success) {
          self.refreshBalances()
          jQuery("#EmailPassword").html(jQuery("#depositPassword1").val())
          jQuery("#SMSPassword").html(jQuery("#depositPassword2").val())
        }
      } else {
        console.error("Error: only positive values acceptable!")
      }
  },

  withdrawEther: async function () {
    let password = jQuery("#withdrawPassword").val()
    let txHash = await instance.withdrawEther.sendTransaction(password, { from: remitter })
    let success = await this.followUpTransaction(txHash);
    if(success) {
      this.refreshBalances()
      jQuery("#withdrawn").html("Funds you deposited to address " + remitter + " have been withdrawn").show().delay(5000).fadeOut()
    }
  },

  claimBackEther: async function () {
    let password = jQuery("#depositPassword1").val() + jQuery("#depositPassword2").val()
    let hash = await instance.calculateHash(password, remitter, { from: sender })
    let txHash = await instance.claimBackEther.sendTransaction( hash, { from: sender })
    let success = await this.followUpTransaction(txHash);
    if(success) {
      this.refreshBalances()
    }
  },

  changeClaimBackPeriods: async function() {
    let revertPeriod = jQuery("#revertPeriod").val()
    let claimBackPeriod = jQuery("#claimBackPeriod").val()
    let txHash = await instance.changeClaimBackPeriods.sendTransaction(
        revertPeriod, claimBackPeriod, { from: owner })
    let success = await this.followUpTransaction(txHash)
    if(success) {
      jQuery("#periodsUpdated").html("Periods have been updated").show().delay(5000).fadeOut()
    }
  }
}

function convertToEther(value) {
  return web3.fromWei(value.toString(10), "ether");
}

function convertToWei(value) {
  return web3.toWei(value, "ether");
}
