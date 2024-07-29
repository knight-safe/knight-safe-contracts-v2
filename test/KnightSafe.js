const { expect } = require("chai");
const { ethers } = require("hardhat");
const {
  loadFixture,
  time,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");

const addressZero = "0x0000000000000000000000000000000000000000";
const addressOne = "0x0000000000000000000000000000000000000001";

async function deployMasterCopy() {
  const [owner] = await ethers.getSigners();

  const masterCopy = await ethers.deployContract("KnightSafe");

  return { masterCopy, owner };
}

async function deployProxyFactory() {
  const proxyFactory = await ethers.deployContract("KnightSafeProxyFactory");

  return { proxyFactory };
}

async function deployKnightSafe() {
  const { masterCopy, owner } = await loadFixture(deployMasterCopy);
  const mcAddr = await masterCopy.getOwner();
  console.log({ mcAddr });
  const { proxyFactory } = await loadFixture(deployProxyFactory);

  const setupData = masterCopy.interface.encodeFunctionData("initialize", [
    owner.address,
  ]);
  const tx = await proxyFactory.createProxy(masterCopy.target, setupData);
  const rc = await tx.wait();

  const event = rc.logs.find((event) => event.address == proxyFactory.target);
  const proxy = ethers.getAddress(event.data.slice(26, 66));

  const Delegate = await ethers.getContractFactory("KnightSafe");
  const knightSafe = await Delegate.attach(proxy);

  // const sendEth = await owner.sendTransaction({to: knightSafe.target, value: ethers.parseUnits("10", "ether")});

  return { knightSafe, owner };
}

async function deployKnightSafeWithAdmin() {
  const { knightSafe, owner } = await loadFixture(deployKnightSafe);
  addresses = await ethers.getSigners();

  admin1 = addresses[11];
  admin2 = addresses[12];

  await knightSafe.addAdmin(admin1.address);
  await knightSafe.addAdmin(admin2.address);

  return { knightSafe, owner, admin1, admin2 };
}

async function deployKnightSafeWithAdminAndPolicyGroups() {
  const { knightSafe, owner } = await loadFixture(deployKnightSafe);
  addresses = await ethers.getSigners();

  admin1 = addresses[11];
  admin2 = addresses[12];
  trader1 = addresses[16];
  trader2 = addresses[17];
  trader3 = addresses[18];

  await knightSafe.addAdmin(admin1.address);
  await knightSafe.addAdmin(admin2.address);

  await knightSafe.createPolicy();
  await knightSafe.createPolicy();

  await knightSafe.addTrader(1, trader1.address);
  await knightSafe.addTrader(2, trader2.address);
  await knightSafe.addTrader(1, trader3.address);
  await knightSafe.addTrader(2, trader3.address);

  return { knightSafe, owner, admin1, admin2, trader1, trader2, trader3 };
}

async function getReqIdFromTx(tx, knightSafe) {
  const rc = await tx.wait();
  const event = rc.logs.find((event) => event.address == knightSafe.target);
  const reqId = parseInt(event.topics[1]);
  return reqId;
}

describe("Deploy test case", function () {
  describe("Deploy Master Copy", function () {
    it("deployed master copy should have owner = 0x1", async function () {
      const { masterCopy, owner } = await loadFixture(deployMasterCopy);

      expect(await masterCopy.getOwner()).to.equal(addressOne);
    });

    it("Master copy's setup should not be able to call", async function () {
      const { masterCopy, owner } = await loadFixture(deployMasterCopy);

      await expect(
        masterCopy.initialize(owner.address)
      ).to.be.revertedWithCustomError(masterCopy, "InvalidOperation");
    });
  });

  describe("Deploy Proxy Factory", function () {
    it("proxy factory should be non-zero address", async function () {
      const { proxyFactory } = await loadFixture(deployProxyFactory);

      expect(proxyFactory.target).to.not.equal(addressZero);
    });
  });

  describe("Deploy Knight Safe", function () {
    it("Basic setups", async function () {
      const { knightSafe, owner } = await loadFixture(deployKnightSafe);

      expect(await knightSafe.getOwner()).to.equal(owner.address);
      expect(await knightSafe.getActivePolicyIds()).to.have.length(1);
      expect(await knightSafe.getAdmins()).to.have.length(0);
      // expect(await ethers.provider.getBalance(knightSafe.target)).to.equal(ethers.parseUnits("10", "ether"));
    });

    it("Owner Manager, backup owner", async function () {
      const { knightSafe, owner } = await loadFixture(deployKnightSafe);
      addresses = await ethers.getSigners();

      backupOwner = addresses[11];
      notBackupOwner = addresses[12];

      expect(await knightSafe.getBackupOwner()).to.eql([addressZero, 0n]);
      await expect(
        knightSafe.setBackupOwner(addressZero, 0)
      ).to.be.revertedWithCustomError(knightSafe, "InvalidAddress");
      await expect(
        knightSafe.setBackupOwner(knightSafe.target, 0)
      ).to.be.revertedWithCustomError(knightSafe, "InvalidAddress");

      await knightSafe.setBackupOwner(backupOwner.address, 3600);
      expect(await knightSafe.getBackupOwner()).to.eql([
        backupOwner.address,
        3600n,
      ]);

      await expect(
        knightSafe.connect(backupOwner).instantTakeover()
      ).to.be.revertedWithCustomError(knightSafe, "TakeoverIsNotReady");
      await expect(
        knightSafe.connect(backupOwner).confirmTakeover()
      ).to.be.revertedWithCustomError(knightSafe, "InvalidTakeoverStatus");

      await expect(
        knightSafe.connect(notBackupOwner).requestTakeover()
      ).to.be.revertedWithCustomError(knightSafe, "Unauthorized");
      await knightSafe.connect(backupOwner).requestTakeover();
      await expect(
        knightSafe.connect(backupOwner).confirmTakeover()
      ).to.be.revertedWithCustomError(knightSafe, "TakeoverIsNotReady");

      await time.increase(3600);
      await knightSafe.connect(backupOwner).confirmTakeover();

      expect(await knightSafe.getOwner()).to.equal(backupOwner.address);

      await knightSafe.connect(backupOwner).setBackupOwner(owner.address, 0);
      await knightSafe.instantTakeover();
      expect(await knightSafe.getOwner()).to.equal(owner.address);
    });

    it("Owner Manager, admins", async function () {
      const { knightSafe, owner } = await loadFixture(deployKnightSafe);
      addresses = await ethers.getSigners();

      admin1 = addresses[11];
      admin2 = addresses[12];

      await knightSafe.addAdmin(admin1.address);
      expect((await knightSafe.getAdmins())[0]).to.equal(admin1.address);

      await expect(
        knightSafe.connect(admin1).addAdmin(admin2.address)
      ).to.be.revertedWithCustomError(knightSafe, "Unauthorized");

      await expect(
        knightSafe.addAdmin(admin1.address)
      ).to.be.revertedWithCustomError(knightSafe, "AddressAlreadyExist");

      expect(await knightSafe.isAdmin(admin2.address)).to.be.false;
      await knightSafe.addAdmin(admin2.address);
      expect(await knightSafe.isAdmin(admin2.address)).to.be.true;

      await expect(
        knightSafe.connect(admin1).removeAdmin(admin2.address)
      ).to.be.revertedWithCustomError(knightSafe, "Unauthorized");

      await knightSafe.removeAdmin(admin2.address);
      expect(await knightSafe.getAdmins()).to.have.length(1);
    });

    it("Policy Group, create and remove", async function () {
      const { knightSafe, owner, admin1, admin2 } = await loadFixture(
        deployKnightSafeWithAdmin
      );

      await knightSafe.createPolicy();
      expect(await knightSafe.isActivePolicy(1)).to.be.true;

      await expect(
        knightSafe.connect(admin1).createPolicy()
      ).to.be.revertedWithCustomError(knightSafe, "Unauthorized");
      await knightSafe.createPolicy();
      expect(await knightSafe.isActivePolicy(2)).to.be.true;

      await knightSafe.connect(admin1).removePolicy(1);
      expect(await knightSafe.isActivePolicy(1)).to.be.false;

      await knightSafe.removePolicy(2);
      expect(await knightSafe.isActivePolicy(2)).to.be.false;
      await expect(knightSafe.removePolicy(2)).to.be.revertedWithCustomError(
        knightSafe,
        "PolicyNotExist"
      );

      expect(await knightSafe.isActivePolicy(0)).to.be.true;
      await expect(knightSafe.removePolicy(0)).to.be.revertedWithCustomError(
        knightSafe,
        "InvalidOperation"
      );
    });

    it("Policy Group, traders", async function () {
      const { knightSafe, owner, admin1, admin2 } = await loadFixture(
        deployKnightSafeWithAdmin
      );
      addresses = await ethers.getSigners();

      trader1 = addresses[16];
      trader2 = addresses[17];

      await knightSafe.createPolicy();

      expect(await knightSafe.getTraders(1)).to.have.length(0);

      // Owner can add trader
      await knightSafe.addTrader(1, trader1.address);
      expect((await knightSafe.getTraders(1))[0]).to.equal(trader1.address);

      // Trader already in Policy
      await expect(
        knightSafe.addTrader(1, trader1.address)
      ).to.be.revertedWithCustomError(knightSafe, "AddressAlreadyExist");
      // Policy not exist
      await expect(
        knightSafe.addTrader(2, trader1.address)
      ).to.be.revertedWithCustomError(knightSafe, "PolicyNotExist");
      // Admin cannot add trader
      await expect(
        knightSafe.connect(admin1).addTrader(1, trader1.address)
      ).to.be.revertedWithCustomError(knightSafe, "Unauthorized");

      expect(await knightSafe.isTrader(1, trader1.address)).to.be.true;
      expect(await knightSafe.isTrader(2, trader1.address)).to.be.false;
      expect(await knightSafe.isTrader(1, trader2.address)).to.be.false;

      await knightSafe.addTrader(1, trader2.address);
      expect(await knightSafe.getTraders(1)).to.be.eql([
        trader1.address,
        trader2.address,
      ]);

      // Admin can remove trader
      await knightSafe.connect(admin1).removeTrader(1, trader1.address);
      expect((await knightSafe.getTraders(1))[0]).to.equal(trader2.address);

      // Trader not exist
      await expect(
        knightSafe.removeTrader(1, trader1.address)
      ).to.be.revertedWithCustomError(knightSafe, "AddressNotExist");

      // Owner can remove trader
      await knightSafe.removeTrader(1, trader2.address);
      expect(await knightSafe.getTraders(1)).to.have.length(0);

      await knightSafe.addTrader(1, trader1.address);
      expect((await knightSafe.getTraders(1))[0]).to.equal(trader1.address);

      await knightSafe.removePolicy(1);
      expect(await knightSafe.getTraders(1)).to.have.length(1);
    });

    it("PolicyGroup, whitelists", async function () {
      const { knightSafe, owner, admin1, admin2, trader1, trader2, trader3 } =
        await loadFixture(deployKnightSafeWithAdminAndPolicyGroups);

      const sampleKsa = await ethers.deployContract("SampleKnightSafeAnalyser");
      // const invalidKsa = await ethers.deployContract("InvalidKnightSafeAnalyser");

      const whitelist0 = "0x0000000000000000000000000000000000001000";
      const whitelist1 = "0x0000000000000000000000000000000000001001";
      const whitelist2 = "0x0000000000000000000000000000000000001002";
      // const whitelist3 = "0x0000000000000000000000000000000000001003";

      await knightSafe.updateWhitelist(1, whitelist0, addressZero);
      await knightSafe.updateWhitelist(1, whitelist1, addressOne);
      await knightSafe.updateWhitelist(1, whitelist2, sampleKsa.target);
      // await expect(knightSafe.updateWhitelist(1, whitelist3, invalidKsa.target)).to.be.revertedWithCustomError(knightSafe, "AddressIsNotKnightSafeAnalyser");

      expect(await knightSafe.isPolicyWhitelistAddress(1, whitelist1)).to.be
        .true;
      expect(await knightSafe.isPolicyWhitelistAddress(2, whitelist1)).to.be
        .false;

      // Trader in Policy with whitelist can requst
      await knightSafe
        .connect(trader1)
        .requestTransaction(1, whitelist1, 0, "0x12345678");
      expect(await knightSafe.getNextTransactionRequestId()).to.equal(1);

      // Trade cannot request on behalf of Policy not belong to
      await expect(
        knightSafe
          .connect(trader2)
          .requestTransaction(1, whitelist1, 0, "0x12345678")
      ).to.be.revertedWithCustomError(knightSafe, "Unauthorized");
      // Trader in Policy without whitelist can also requst
      await knightSafe
        .connect(trader2)
        .requestTransaction(2, whitelist1, 0, "0x12345678");
      expect(await knightSafe.getNextTransactionRequestId()).to.equal(2);

      // trader not in group cannot execute req
      await expect(
        knightSafe.connect(trader2).executeTransactionByReqId(1, false, 0)
      ).to.be.revertedWithCustomError(knightSafe, "Unauthorized");
      // group have no whitelist cannot execute req
      await expect(
        knightSafe.connect(trader2).executeTransactionByReqId(2, false, 0)
      ).to.be.revertedWithCustomError(knightSafe, "AddressNotInWhitelist");
      // Req status = pending
      expect((await knightSafe.getTransactionRequest(0)).status).to.equal(0);
      // Execute Success
      await knightSafe.connect(trader1).executeTransactionByReqId(1, false, 0);
      // Req status = completed
      expect((await knightSafe.getTransactionRequest(0)).status).to.equal(2);
      // req already complete cannot execute again
      await expect(
        knightSafe.connect(trader1).executeTransactionByReqId(1, false, 0)
      ).to.be.revertedWithCustomError(knightSafe, "InvalidTransactionStatus");

      // Req sender cannot reject if not in policy
      await expect(
        knightSafe.connect(trader2).rejectTransactionByReqId(1, false, 1)
      ).to.be.revertedWithCustomError(knightSafe, "Unauthorized");
      // Only req sender can cancel req
      await expect(
        knightSafe.connect(trader1).cancelTransactionByReqId(1, 1)
      ).to.be.revertedWithCustomError(knightSafe, "InvalidOperation");
      // Req sender can cancel req
      await knightSafe.connect(trader2).cancelTransactionByReqId(2, 1);
      // Req status = cancelled
      expect((await knightSafe.getTransactionRequest(1)).status).to.equal(1);
      // Cancelled req cannot be cancelled again
      await expect(
        knightSafe.connect(trader2).cancelTransactionByReqId(2, 1)
      ).to.be.revertedWithCustomError(knightSafe, "InvalidTransactionStatus");

      await knightSafe
        .connect(trader2)
        .requestTransaction(2, whitelist1, 0, "0x12345678");
      await knightSafe
        .connect(trader2)
        .requestTransaction(2, whitelist1, 0, "0x12345678");
      expect(await knightSafe.getNextTransactionRequestId()).to.equal(4);

      // Req sender cannot reject if policy no permission
      await expect(
        knightSafe.connect(trader2).rejectTransactionByReqId(2, false, 2)
      ).to.be.revertedWithCustomError(knightSafe, "AddressNotInWhitelist");
      // Reject success
      await knightSafe.connect(trader1).rejectTransactionByReqId(1, false, 2);
      // Req status = rejected
      expect((await knightSafe.getTransactionRequest(2)).status).to.equal(3);
      // Rejected req cannot be rejected again
      await expect(
        knightSafe.connect(trader1).rejectTransactionByReqId(1, false, 2)
      ).to.be.revertedWithCustomError(knightSafe, "InvalidTransactionStatus");
      // Rejected req cannot be executed
      await expect(
        knightSafe.connect(trader1).executeTransactionByReqId(1, false, 2)
      ).to.be.revertedWithCustomError(knightSafe, "InvalidTransactionStatus");

      await expect(
        knightSafe
          .connect(trader1)
          .executeTransaction(1, false, whitelist1, 0, "0x12345678")
      ).to.not.be.reverted;
      await expect(
        knightSafe
          .connect(trader1)
          .executeTransaction(2, false, whitelist1, 0, "0x12345678")
      ).to.be.revertedWithCustomError(knightSafe, "Unauthorized");
      await expect(
        knightSafe
          .connect(trader2)
          .executeTransaction(2, false, whitelist1, 0, "0x12345678")
      ).to.be.revertedWithCustomError(knightSafe, "AddressNotInWhitelist");
    });

    it("PolicyGroup, global trader and whitelist", async function () {
      const { knightSafe, owner, admin1, admin2, trader1, trader2, trader3 } =
        await loadFixture(deployKnightSafeWithAdminAndPolicyGroups);

      const sampleKsa = await ethers.deployContract("SampleKnightSafeAnalyser");

      const whitelist0 = "0x0000000000000000000000000000000000001000";
      const whitelist1 = "0x0000000000000000000000000000000000001001";
      const whitelist1111 = "0x1111111111111111111111111111111111111111";
      const whitelist2222 = "0x2222222222222222222222222222222222222222";

      let tx, reqId;

      await knightSafe.updateWhitelist(0, whitelist0, addressOne);
      await knightSafe.updateWhitelist(0, whitelist1111, addressZero);
      await knightSafe.updateWhitelist(1, whitelist1, sampleKsa.target);
      await knightSafe.updateWhitelist(1, whitelist2222, addressZero);

      expect(await knightSafe.isPolicyWhitelistAddress(0, whitelist0)).to.be
        .true;
      expect(await knightSafe.isPolicyWhitelistAddress(0, whitelist1)).to.be
        .false;

      // Using global whitelist, self approve
      await expect(
        knightSafe
          .connect(trader1)
          .executeTransaction(1, false, whitelist0, 0, "0x12345678")
      ).to.be.revertedWithCustomError(knightSafe, "AddressNotInWhitelist");
      await expect(
        knightSafe
          .connect(trader1)
          .executeTransaction(1, true, whitelist0, 0, "0x12345678")
      ).to.not.be.reverted;

      // Using global whitelist, reject request
      tx = await knightSafe
        .connect(trader1)
        .requestTransaction(1, whitelist0, 0, "0x12345678");
      reqId = await getReqIdFromTx(tx, knightSafe);

      expect((await knightSafe.getTransactionRequest(reqId)).status).to.equal(
        0
      );
      await expect(
        knightSafe.connect(trader2).rejectTransactionByReqId(2, false, reqId)
      ).to.be.revertedWithCustomError(knightSafe, "AddressNotInWhitelist");
      await expect(
        knightSafe.connect(trader2).rejectTransactionByReqId(2, true, reqId)
      ).to.not.be.reverted;

      // Using global whitelist, approve request
      tx = await knightSafe
        .connect(trader1)
        .requestTransaction(1, whitelist0, 0, "0x12345678");
      reqId = await getReqIdFromTx(tx, knightSafe);

      expect((await knightSafe.getTransactionRequest(reqId)).status).to.equal(
        0
      );
      await expect(
        knightSafe.connect(trader2).executeTransactionByReqId(2, false, reqId)
      ).to.be.revertedWithCustomError(knightSafe, "AddressNotInWhitelist");
      await expect(
        knightSafe.connect(trader2).executeTransactionByReqId(2, true, reqId)
      ).to.not.be.reverted;

      // KSA that need whitelist address from local and global whitelist
      await expect(
        knightSafe
          .connect(trader1)
          .executeTransaction(1, true, whitelist1, 0, "0x11111111")
      ).to.be.revertedWithCustomError(knightSafe, "AddressNotInWhitelist");
      await expect(
        knightSafe
          .connect(trader1)
          .executeTransaction(1, false, whitelist1, 0, "0x11111111")
      ).to.not.be.reverted;

      // add trader3 to global trader
      await knightSafe.addTrader(0, trader3.address);
      expect(await knightSafe.isTrader(0, trader3.address)).to.be.true;

      // Global trader can operator as if they are local trader of any group
      await expect(
        knightSafe
          .connect(trader3)
          .executeTransaction(1, false, whitelist0, 0, "0x12345678")
      ).to.be.revertedWithCustomError(knightSafe, "AddressNotInWhitelist");
      await expect(
        knightSafe
          .connect(trader3)
          .executeTransaction(1, true, whitelist0, 0, "0x12345678")
      ).to.not.be.reverted;

      tx = await knightSafe
        .connect(trader3)
        .requestTransaction(1, whitelist0, 0, "0x12345678");
      reqId = await getReqIdFromTx(tx, knightSafe);
      expect((await knightSafe.getTransactionRequest(reqId)).status).to.equal(
        0
      );
      await expect(
        knightSafe.connect(trader3).rejectTransactionByReqId(2, false, reqId)
      ).to.be.revertedWithCustomError(knightSafe, "AddressNotInWhitelist");
      await expect(
        knightSafe.connect(trader3).rejectTransactionByReqId(2, true, reqId)
      ).to.not.be.reverted;

      tx = await knightSafe
        .connect(trader3)
        .requestTransaction(1, whitelist0, 0, "0x12345678");
      reqId = await getReqIdFromTx(tx, knightSafe);
      expect((await knightSafe.getTransactionRequest(reqId)).status).to.equal(
        0
      );
      await expect(
        knightSafe.connect(trader3).executeTransactionByReqId(2, false, reqId)
      ).to.be.revertedWithCustomError(knightSafe, "AddressNotInWhitelist");
      await expect(
        knightSafe.connect(trader3).executeTransactionByReqId(2, true, reqId)
      ).to.not.be.reverted;

      await expect(
        knightSafe
          .connect(trader3)
          .executeTransaction(1, true, whitelist1, 0, "0x11111111")
      ).to.be.revertedWithCustomError(knightSafe, "AddressNotInWhitelist");
      await expect(
        knightSafe
          .connect(trader3)
          .executeTransaction(1, false, whitelist1, 0, "0x11111111")
      ).to.not.be.reverted;
    });
  });
});
