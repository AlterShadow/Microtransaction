import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@openzeppelin/hardhat-upgrades";

const config: HardhatUserConfig = {
  // defaultNetwork: "sepolia",
  networks: {
    hardhat: {},
    sepolia: {
      url: "https://eth-sepolia.g.alchemy.com/v2/uCORp6v8AFu144PO-uqbHfziTfmaNml7",
      accounts: [
        "c7504096ecdb86e9c5a576da03e5e3e8bf8af70e5f92a8b6b825188b677f8f4f",
      ],
    },
  },
  solidity: "0.8.24",
};

export default config;
