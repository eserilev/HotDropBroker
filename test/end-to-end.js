const { expect } = require("chai");
const { ethers } = require("hardhat");

describe('End To End', function () {
    var accounts;
    var hotDropFactory;
    var hotDropBroker;
    var fakeNFT;
    before(async() => {
        accounts = await ethers.getSigners();
        const FakeNFT = await ethers.getContractFactory("FakeNFT");
        const HotDropFactory = await ethers.getContractFactory("HotDropFactory");
        const HotDropBroker = await ethers.getContractFactory("HotDropBroker");
        
        fakeNFT = await FakeNFT.deploy();
        await fakeNFT.deployed();

        hotDropFactory = await HotDropFactory.deploy();
        await hotDropFactory.deployed();

        hotDropBroker = await HotDropBroker.deploy(hotDropFactory.address, accounts[0].address, 1);
        await hotDropBroker.deployed();
    })
    it("Broker contract should have reference to factory contract address", async() => {
        expect(await hotDropBroker.hotDropFactory()).to.equal(hotDropFactory.address);     
    });
    it("New NFT project should have a project id", async() => {
        expect(await hotDropFactory.createProject(fakeNFT.address, 'test')).to.not.be.empty;
    });
    it("NFT project address should be accessible via project ID", async() => {
        expect(await hotDropFactory.projectIdToTokenAddress(1)).to.not.be.empty;
    });
    it("Check if factory contract reverts when trying to create project w/ non nft contract", async() => {
        await expect(hotDropFactory.createProject(accounts[0].address, 'test')).to.be.reverted;
    });
    it("Places an order", async() => {
        await hotDropBroker.placeOrder(1,1, {
            value: ethers.utils.parseEther("1.0")
        });
        expect(await hotDropBroker.balances(accounts[0].address)).to.not.be.equal(0);
    });
    it("Fulfills an order", async() => {
        await fakeNFT.dropNFT(accounts[0].address);
        await fakeNFT.approve(hotDropBroker.address, 1);
        await hotDropBroker.fulfillOrder(accounts[0].address, 1, 1, ethers.utils.parseEther("1.0"), accounts[0].address);
    });
});
