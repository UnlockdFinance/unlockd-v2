import * as dotenv from "dotenv";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
// import { ethers } from "hardhat";

import { DelegationRecipes, DelegationWalletRegistry } from "../typechain-types";

dotenv.config();

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, ethers } = hre;
  const { deploy } = deployments;

  // const {deployer} = await getNamedAccounts();
  const { deployer } = await hre.ethers.getNamedSigners();

  const requiredEnvs = ["COMPATIBILITY_FALLBACK_HANDLER", "GNOSIS_SAFE_TEMPLATE", "GNOSIS_SAFE_PROXY_FACTORY"];
  for (const env of requiredEnvs) {
    if (!process.env[env]) {
      throw new Error(`${env} is not set`);
    }
  }

  const testNft = await deploy("TestNft", {
    from: deployer.address,
    args: [],
    log: true,
    autoMine: true,
  });

  const testPunks = await deploy("TestPunks", {
    from: deployer.address,
    args: [],
    log: true,
    autoMine: true,
  });

  const testNftPlatform = await deploy("TestNftPlatform", {
    from: deployer.address,
    args: [testNft.address],
    log: true,
    autoMine: true,
  });

  const allowedControllers = await deploy("AllowedControllers", {
    from: deployer.address,
    args: [[], []],
    log: true,
    autoMine: true,
  });

  const delegationRecipes = await deploy("DelegationRecipes", {
    from: deployer.address,
    args: [],
    log: true,
    autoMine: true,
  });

  const safeOwnerImpl = await deploy("DelegationOwnerImplementation", {
    from: deployer.address,
    contract: "DelegationOwner",
    args: [testPunks.address, delegationRecipes.address, allowedControllers.address],
    log: true,
    autoMine: true,
  });

  const safeGuardImpl = await deploy("DelegationGuardImplementation", {
    from: deployer.address,
    contract: "DelegationGuard",
    args: [testPunks.address],
    log: true,
    autoMine: true,
  });

  const safeOwnerBeacon = await deploy("DelegationOwnerBeacon", {
    from: deployer.address,
    contract: "UpgradeableBeacon",
    args: [safeOwnerImpl.address],
    log: true,
    autoMine: true,
  });

  const safeGuardBeacon = await deploy("DelegationGuardBeacon", {
    from: deployer.address,
    contract: "UpgradeableBeacon",
    args: [safeGuardImpl.address],
    log: true,
    autoMine: true,
  });

  const delegationWalletRegistry = await deploy("DelegationWalletRegistry", {
    from: deployer.address,
    args: [],
    log: true,
    autoMine: true,
  });

  const rentalsFactory = await deploy("DelegationWalletFactory", {
    from: deployer.address,
    args: [
      process.env.GNOSIS_SAFE_PROXY_FACTORY,
      process.env.GNOSIS_SAFE_TEMPLATE,
      process.env.COMPATIBILITY_FALLBACK_HANDLER,
      safeGuardBeacon.address,
      safeOwnerBeacon.address,
      delegationWalletRegistry.address,
    ],
    log: true,
    autoMine: true,
  });

  const delegationWalletRegistryContract = (await ethers.getContractAt(
    "DelegationWalletRegistry",
    delegationWalletRegistry.address,
    deployer,
  )) as DelegationWalletRegistry;

  console.log("Configuring DelegationWalletRegistry...");
  await (await delegationWalletRegistryContract.setFactory(rentalsFactory.address)).wait();
  console.log("done...");

  const delegationRecipesContract = (await ethers.getContractAt(
    "DelegationRecipes",
    delegationRecipes.address,
    deployer,
  )) as DelegationRecipes;

  console.log("Configuring DelegationRecipes...");
  await (
    await delegationRecipesContract.add(
      testNft.address,
      [testNftPlatform.address],
      ["0x4816cbdf"],
      ["TestNftPlatform - allowedFunction"],
    )
  ).wait();
  console.log("done...");
};

export default func;
