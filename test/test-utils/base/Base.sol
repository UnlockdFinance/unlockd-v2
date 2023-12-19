// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import '../mock/asset/MintableERC20.sol';
import '../mock/yearn/MockYVault.sol';
import {stdStorage, StdStorage, Test} from 'forge-std/Test.sol';
import {ReserveOracle} from '../../../src/libraries/oracles/ReserveOracle.sol';
import {Unlockd} from '../../../src/protocol/Unlockd.sol';
// import {UToken} from '../../../src/protocol/UToken.sol';
import {ACLManager} from '../../../src/libraries/configuration/ACLManager.sol';
import {DataTypes, Constants} from '../../../src/types/DataTypes.sol';
import {stdStorage, StdStorage, Test} from 'forge-std/Test.sol';
import '../config/Config.sol';

contract Base is Test {
  uint256 internal constant MAINNET = 1;
  uint256 internal constant SEPOLIA = 11155111;
  // Static Addreses for the TESTS
  uint256 public _treasuryPK = 0x222222DEAD;
  address internal _treasury = vm.addr(_treasuryPK);

  uint256 public _deployerPK = 0x111111DEAD;
  address internal _deployer = vm.addr(_deployerPK);

  // Generate signer
  uint256 public _signerPrivateKey = 0xC0C0;
  address public _signer = vm.addr(_signerPrivateKey);

  uint256 public _signerTwoPrivateKey = 0xDADA;
  address public _signerTwo = vm.addr(_signerTwoPrivateKey);

  // Admins

  uint256 public _adminPK = 0xC0C00DEAD;
  address internal _admin = vm.addr(_adminPK);

  uint256 public _adminUpdaterPK = 0xCACA0DEAD;
  address internal _adminUpdater = vm.addr(_adminUpdaterPK);

  ACLManager internal _aclManager;

  mapping(string => address) _uTokens;

  Unlockd internal _unlock;

  // Oracles
  address internal _reserveOracle;

  // Adapter
  address internal _reservoirAdapter;
  address internal _mockAdapter;
  address internal _maxApyStrategy;
  address internal _maxApy;
  address internal _interestRate;
  // Wallet Factory
  address internal _walletRegistry;
  address internal _walletFactory;
  address internal _allowedControllers;

  Config.ChainConfig internal config;

  function setUpForkChain(uint256 chainId) internal {
    config = Config.getConfig(chainId);
    // Chain FORK
    uint256 chainFork = vm.createFork(config.chainName, config.blockNumber);
    vm.selectFork(chainFork);
  }

  modifier useFork(uint256 chainId) {
    setUpForkChain(chainId);
    _;
  }

  // ====== GET =========
  function getACLManager() internal view returns (ACLManager) {
    return _aclManager;
  }

  function getUToken(string memory name) internal view returns (address) {
    return _uTokens[name];
  }

  function getUnlockd() internal view returns (Unlockd) {
    return _unlock;
  }
}
