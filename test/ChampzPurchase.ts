import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import hre, { ethers } from "hardhat";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { Contract } from "ethers";
import { ChampzPurchase as ChampzPurchaseType } from "../typechain-types";

describe("ChampzPurchase Tests", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  let ChampzPurchase, champzPurchase: ChampzPurchaseType;
  let owner: HardhatEthersSigner,
    addr1: HardhatEthersSigner,
    paymentReceiver: HardhatEthersSigner;

  function encodePackedUint256Array(array: Array<number> | Array<bigint>) {
    // Convert each element of the array to a hex string
    // and concatenate them into a single string.
    return array
      .map((num) => ethers.zeroPadValue(ethers.toBeHex(num), 32))
      .map((hexStr) => hexStr.slice(2)) // Remove '0x' prefix from each element
      .join("");
  }

  // Runs before each test: deploy a new ChampzPurchase contract
  beforeEach(async function () {
    // Getting the signers
    [owner, addr1, paymentReceiver] = await hre.ethers.getSigners();

    console.log(owner.address, addr1.address, paymentReceiver.address);

    // Getting the contract factory
    ChampzPurchase = await hre.ethers.getContractFactory("ChampzPurchase");

    // Deploying the contract as an upgradeable proxy
    champzPurchase = (await hre.upgrades.deployProxy(
      ChampzPurchase,
      [], // initialSporePrice as an example
      { initializer: "initialize" }
    )) as unknown as ChampzPurchaseType;
    await champzPurchase.waitForDeployment();

    console.log(
      "ChampzPurchase deployed to: ",
      await champzPurchase.getAddress()
    );
  });

  describe("Deployment and Initialization", function () {
    it("Should set the right owner", async function () {
      // The owner should be the first signer
      expect(await champzPurchase.owner()).to.equal(owner.address);
    });
  });

  describe("Test purchase function", function () {
    it("Should allow a correct purchase with valid signature", async function () {
      // Sample data for the test
      const bundleIds = [1, 2];
      const prices = [hre.ethers.parseEther("1"), hre.ethers.parseEther("2")];
      const totalCost = hre.ethers.parseEther("3"); // Ensure this matches sporeAmounts * sporePrice
      //   console.log(await hre.ethers.provider.getBalance(addr1.address));

      // Generate a timestamp
      const timestamp = Math.floor(Date.now() / 1000); // Just an example, adjust based on your contract needs

      // Encode each array into a single hex string
      const encodedBundleIds = encodePackedUint256Array(bundleIds);
      const encodedPrices = encodePackedUint256Array(prices);

      // Concatenate the encoded strings
      const concatenatedHex = "0x" + encodedBundleIds + encodedPrices;

      //   console.log(concatenatedHex);
      // Hash the concatenated hex string
      const purchasesHash = hre.ethers.keccak256(concatenatedHex);
      //   console.log(purchasesHash);

      const Claim = hre.ethers.toUtf8Bytes("Purchase");
      const Timestamp = hre.ethers.toUtf8Bytes("Timestamp");
      const Champz = hre.ethers.toUtf8Bytes("Champz");

      const timestampStr = hre.ethers.zeroPadValue(
        hre.ethers.toBeHex(timestamp),
        32
      );

      const claimStr = Claim.reduce((prevValue, currentValue) => {
        return prevValue + ethers.toBeHex(currentValue).slice(2);
      }, "");

      const timestampStrr = Timestamp.reduce((prevValue, currentValue) => {
        return prevValue + ethers.toBeHex(currentValue).slice(2);
      }, "");

      const champzStr = Champz.reduce((prevValue, currentValue) => {
        return prevValue + ethers.toBeHex(currentValue).slice(2);
      }, "");

      const rawMessage =
        "0x" +
        claimStr +
        addr1.address.slice(2) +
        timestampStrr +
        timestampStr.slice(2) +
        champzStr +
        purchasesHash.slice(2);

      const messageHash = hre.ethers.keccak256(rawMessage);

      // Signing the message
      // Assuming the signer is the same as `owner` in this test
      const signature = await owner.signMessage(
        hre.ethers.getBytes(messageHash)
      );

      // Calculating total cost if not a fixed value
      // let totalCost = sporeAmounts.length * SINGLE_SPORE_COST; // Define SINGLE_SPORE_COST
      // For simplicity, assuming a fixed `totalCost` is used here

      // Making the purchase. The value should match the expected total cost.
      await expect(
        champzPurchase
          .connect(addr1)
          .purchase(timestamp, signature, bundleIds, prices, {
            value: totalCost,
          })
      )
        .to.emit(champzPurchase, "SporeBundlesPurchased")
        .withArgs(addr1.address, bundleIds, prices);

      // Further checks can include validating state changes (e.g., `claimedBundle`)
      for (let bundleId of bundleIds) {
        expect(await champzPurchase.claimedBundle(bundleId)).to.be.true;
      }

      //   console.log(await hre.ethers.provider.getBalance(addr1.address));
    });
  });
});
