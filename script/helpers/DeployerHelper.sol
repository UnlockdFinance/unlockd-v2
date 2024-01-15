pragma solidity ^0.8.0;

import 'forge-std/Vm.sol';
import 'forge-std/StdJson.sol';
import 'forge-std/Script.sol';

import '@openzeppelin/contracts/utils/Strings.sol';

contract DeployerHelper is Script {
  using stdJson for string;

  struct Addresses {
    address deployer;
    address aclManager;
    address uTokenFactory;
    address unlockd;
    address walletFactory;
    address walletRegistry;
    address allowedControllers;
    address reserveOracle;
    address adapter;
    address strategy;
  }

  string constant path = './deployments/deploy-';

  modifier broadcast() {
    vm.startBroadcast();
    _;
    vm.stopBroadcast();
  }

  modifier onlyInChain(uint256 chainId) {
    require(chainId == getChainID(), 'chainId not valid');
    _;
  }

  function _decodeJson() internal returns (Addresses memory) {
    try vm.readFile(getFilePath()) returns (string memory persistedJson) {
      Addresses memory addresses = Addresses({
        deployer: abi.decode(persistedJson.parseRaw('.deployer'), (address)),
        aclManager: abi.decode(persistedJson.parseRaw('.aclManager'), (address)),
        uTokenFactory: abi.decode(persistedJson.parseRaw('.uTokenFactory'), (address)),
        unlockd: abi.decode(persistedJson.parseRaw('.unlockd'), (address)),
        walletFactory: abi.decode(persistedJson.parseRaw('.walletFactory'), (address)),
        walletRegistry: abi.decode(persistedJson.parseRaw('.walletRegistry'), (address)),
        allowedControllers: abi.decode(persistedJson.parseRaw('.allowedControllers'), (address)),
        reserveOracle: abi.decode(persistedJson.parseRaw('.reserveOracle'), (address)),
        adapter: abi.decode(persistedJson.parseRaw('.adapter'), (address)),
        strategy: abi.decode(persistedJson.parseRaw('.strategy'), (address))
      });

      return addresses;
    } catch {
      Addresses memory newaddresses = Addresses({
        deployer: address(0),
        aclManager: address(0),
        uTokenFactory: address(0),
        unlockd: address(0),
        walletFactory: address(0),
        walletRegistry: address(0),
        allowedControllers: address(0),
        reserveOracle: address(0),
        adapter: address(0),
        strategy: address(0)
      });
      _encodeJson(newaddresses);
      return newaddresses;
    }
  }

  function _encodeJson(Addresses memory addresses) internal {
    string memory json = 'addresses';

    vm.serializeAddress(json, 'deployer', addresses.deployer);
    vm.serializeAddress(json, 'aclManager', addresses.aclManager);
    vm.serializeAddress(json, 'uTokenFactory', addresses.uTokenFactory);
    vm.serializeAddress(json, 'unlockd', addresses.unlockd);
    vm.serializeAddress(json, 'walletFactory', addresses.walletFactory);
    vm.serializeAddress(json, 'walletRegistry', addresses.walletRegistry);
    vm.serializeAddress(json, 'allowedControllers', addresses.allowedControllers);
    vm.serializeAddress(json, 'reserveOracle', addresses.reserveOracle);
    vm.serializeAddress(json, 'adapter', addresses.adapter);

    string memory output = vm.serializeAddress(json, 'strategy', addresses.strategy);

    vm.writeJson(output, getFilePath());
  }

  // Old compatibility for all the networks
  function getChainID() internal view returns (uint256) {
    uint256 id;
    assembly {
      id := chainid()
    }
    return id;
  }

  function getFilePath() internal view returns (string memory) {
    return
      string(abi.encodePacked(abi.encodePacked(path, Strings.toString(getChainID())), '.json'));
  }
}
