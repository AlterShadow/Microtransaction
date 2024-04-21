import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { ethers } from "ethers";

const ChampzPurchaseModule = buildModule("ChampzPurchaseModule", (m) => {
  const champzPurchase = m.contract("ChampzPurchase", [
    ethers.parseEther("0.01"),
  ]);

  return { champzPurchase };
});

export default ChampzPurchaseModule;
