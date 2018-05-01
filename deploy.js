const HDWalletProvider = require('truffle-hdwallet-provider');
const Web3 = require('web3');
const { interface, bytecode } = require('./compile');

const provider = new HDWalletProvider(
	'<Pneumonic key>',
	'<network to deploy on>'
);
const web3 = new Web3(provider);

deploy();