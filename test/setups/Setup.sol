// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from 'forge-std/console.sol';
import 'forge-std/StdJson.sol';
import {stdStorage, StdStorage, Test} from 'forge-std/Test.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IERC721} from '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import {AllowedControllers} from '@unlockd-wallet/src/libs/allowed/AllowedControllers.sol';
import {DelegationRecipes} from '@unlockd-wallet/src/libs/recipes/DelegationRecipes.sol';
import {TransactionGuard} from '@unlockd-wallet/src/libs/guards/TransactionGuard.sol';
import {DelegationOwner} from '@unlockd-wallet/src/libs/owners/DelegationOwner.sol';
import {ProtocolOwner} from '@unlockd-wallet/src/libs/owners/ProtocolOwner.sol';
import {GuardOwner} from '@unlockd-wallet/src/libs/owners/GuardOwner.sol';
import {DelegationWalletRegistry} from '@unlockd-wallet/src/DelegationWalletRegistry.sol';
import {DelegationWalletFactory} from '@unlockd-wallet/src/DelegationWalletFactory.sol';
import {UpgradeableBeacon} from '@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol';

import '../config/Config.sol';
import '../../src/libraries/proxy/UnlockdUpgradeableProxy.sol';
import './../mock/asset/MintableERC20.sol';
import './../mock/adapters/MockAdapter.sol';
import '../../src/libraries/base/InterestRate.sol';

import '../helpers/HelperNFT.sol'; // solhint-disable-line
import '../helpers/HelperConvert.sol';

import '../base/Base.sol';
import '../base/AssetsBase.sol';
import '../base/ActorsBase.sol';
import '../base/NFTBase.sol';

import {Source} from '../mock/chainlink/Source.sol';

import {DeployPeriphery} from '../../src/deployer/DeployPeriphery.sol';
import {DeployProtocol} from '../../src/deployer/DeployProtocol.sol';
import {DeployUToken} from '../../src/deployer/DeployUToken.sol';
import {DeployUTokenConfig} from '../../src/deployer/DeployUTokenConfig.sol';

import {DebtToken, IDebtToken} from '../../src/protocol/DebtToken.sol';
import {UToken, IUToken} from '../../src/protocol/UToken.sol';

import {Constants} from '../../src/libraries/helpers/Constants.sol';
import {Installer} from '../../src/protocol/modules/Installer.sol';

import {Manager} from '../../src/protocol/modules/Manager.sol';
import {Action} from '../../src/protocol/modules/Action.sol';
import {Auction} from '../../src/protocol/modules/Auction.sol';
import {BuyNow} from '../../src/protocol/modules/BuyNow.sol';
import {SellNow} from '../../src/protocol/modules/SellNow.sol';
import {Market} from '../../src/protocol/modules/Market.sol';

import {ReserveOracle, IReserveOracle} from '../../src/libraries/oracles/ReserveOracle.sol';

import {Unlockd} from '../../src/protocol/Unlockd.sol';
import {DataTypes} from '../../src/types/DataTypes.sol';

import {ACLManager} from '../../src/libraries/configuration/ACLManager.sol';

contract Setup is Base, AssetsBase, ActorsBase, NFTBase {
  using stdStorage for StdStorage;
  using stdJson for string;

  receive() external payable {}

  Config.ChainConfig internal config;

  // *************************************
  function setUp() public virtual {
    // By default Mainnet
    this.setUpByChain(1);
  }

  function setUpForkChain(uint256 chainId) public virtual {
    config = Config.getConfig(chainId);
    // Chain FORK
    uint256 chainFork = vm.createFork(config.chainName, config.blockNumber);
    vm.selectFork(chainFork);
  }

  // Define General Setup
  function setUpByChain(uint256 chainId) public virtual {
    config = Config.getConfig(chainId);

    // Chain FORK
    uint256 chainFork = vm.createFork(config.chainName, config.blockNumber);
    vm.selectFork(chainFork);
    // Set timestamp to March 31, 2023 at 00:00 GMT
    vm.warp(1_680_220_800);

    deploy_acl_manager();

    deploy_mocks();

    deploy_wallet();

    deploy_periphery();

    // Default state

    _uTokens['WETH'] = UToken(deploy_utoken(getAssetAddress('WETH')));
    _uTokens['DAI'] = UToken(deploy_utoken(getAssetAddress('DAI')));

    deploy_protocol();
  }

  // ============= DEPLOYS ===================

  function deploy_acl_manager() internal {
    vm.startPrank(_deployer);
    _aclManager = new ACLManager(_admin);
    vm.stopPrank();
    vm.startPrank(_admin);
    // Configure ADMINS
    _aclManager.addUTokenAdmin(_admin);
    _aclManager.addProtocolAdmin(_admin);
    _aclManager.addGovernanceAdmin(_admin);
    _aclManager.addAuctionAdmin(_admin);
    _aclManager.addEmergencyAdmin(_admin);
    _aclManager.addPriceUpdater(_admin);

    vm.stopPrank();
  }

  function deploy_wallet() internal {
    address[] memory paramsAllowedController;
    AllowedControllers allowedController = new AllowedControllers(
      address(_aclManager),
      paramsAllowedController
    );
    hoax(_admin);
    allowedController.setCollectionAllowance(getNFT('PUNK'), true);
    hoax(_admin);
    allowedController.setCollectionAllowance(getNFT('KITTY'), true);

    DelegationRecipes delegationRecipes = new DelegationRecipes();

    // Declare GUARD
    TransactionGuard guardImp = new TransactionGuard(config.cryptoPunk);

    // Declare implementation guard OWNER
    GuardOwner guardOwnerImpl = new GuardOwner(config.cryptoPunk, address(_aclManager));
    // Declare implementation protocol OWNER
    ProtocolOwner protocolOwnerImpl = new ProtocolOwner(config.cryptoPunk, address(_aclManager));
    // Declare implementation delegation OWNER
    DelegationOwner delegationOwnerImp = new DelegationOwner(
      config.cryptoPunk,
      address(delegationRecipes),
      address(allowedController),
      address(_aclManager)
    );

    // Create beacons
    UpgradeableBeacon safeGuardBeacon = new UpgradeableBeacon(address(guardImp));

    UpgradeableBeacon safeGuardOwnerBeacon = new UpgradeableBeacon(address(guardOwnerImpl));
    UpgradeableBeacon safeDelegationOwnerBeacon = new UpgradeableBeacon(
      address(delegationOwnerImp)
    );
    UpgradeableBeacon safeProtocolOwnerBeacon = new UpgradeableBeacon(address(protocolOwnerImpl));

    DelegationWalletRegistry delegationWalletRegistry = new DelegationWalletRegistry();

    DelegationWalletFactory walletFactory = new DelegationWalletFactory(
      config.gnosisSafeProxyFactory,
      config.gnosisSafeTemplate,
      config.compativilityFallbackHandler,
      address(safeGuardBeacon),
      address(safeGuardOwnerBeacon),
      address(safeDelegationOwnerBeacon),
      address(safeProtocolOwnerBeacon),
      address(delegationWalletRegistry)
    );
    /******************** CONFIG ********************/
    delegationWalletRegistry.setFactory(address(walletFactory));
    _allowedControllers = address(allowedController);
    _walletFactory = address(walletFactory);
    _walletRegistry = address(delegationWalletRegistry);
  }

  function deploy_mocks() internal {
    vm.startPrank(_deployer);
    // Mocks
    _nfts.newAsset('PUNK');
    _nfts.newAsset('KITTY');
    vm.stopPrank();
  }

  function deploy_periphery() internal {
    vm.startPrank(_deployer);
    // ERC20 Assets

    _assets.newAsset('DAI', 18);

    // Deploy Oracles
    DeployPeriphery deployer = new DeployPeriphery(_adminUpdater, address(_aclManager));

    _reserveOracle = deployer.deployReserveOracle(getAssetAddress('WETH'), 1 ether);

    _reservoirAdapter = deployer.deployReservoirMarket(
      config.reservoirRouter,
      0x0000000000000000000000000000000000000000
    );

    _mockAdapter = address(
      new MockAdapter(
        config.reservoirRouter,
        address(_aclManager),
        0x0000000000000000000000000000000000000000
      )
    );

    vm.stopPrank();

    // Configure
    vm.startPrank(_admin);

    // Add DAI to the Oracle
    Source daiSource = new Source();
    ReserveOracle(_reserveOracle).addAggregator(getAssetAddress('DAI'), address(daiSource));

    vm.stopPrank();
  }

  function deploy_utoken(address underlyingAsset) public returns (address) {
    // Deploy Oracles
    DeployUTokenConfig deployerConfig = new DeployUTokenConfig(
      _admin,
      _adminUpdater,
      address(_aclManager)
    );

    // DebtToken
    DeployUTokenConfig.DeployDebtTokenParams memory debtParams = DeployUTokenConfig
      .DeployDebtTokenParams({decimals: 18, tokenName: 'Debt ETH', tokenSymbol: 'DETH'});

    address debtToken = deployerConfig.deployDebtToken(debtParams);

    // Interes Rate
    DeployUTokenConfig.DeployInterestRateParams memory interestParams = DeployUTokenConfig
      .DeployInterestRateParams({
        optimalUtilizationRate: 1 ether,
        baseVariableBorrowRate: 1 ether,
        variableRateSlope1: 1 ether,
        variableRateSlope2: 1 ether
      });
    address interestRate = deployerConfig.deployInterestRate(interestParams);

    DeployUToken.DeployUtokenParams memory utokenParams = DeployUToken.DeployUtokenParams({
      treasury: _treasury,
      underlyingAsset: underlyingAsset,
      decimals: 18,
      tokenName: 'UToken WETH',
      tokenSymbol: 'UWETH',
      debtToken: debtToken,
      reserveFactor: 0,
      interestRate: interestRate
    });

    DeployUToken deployerUToken = new DeployUToken(_admin, address(_aclManager));
    vm.startPrank(_admin);

    _aclManager.addUTokenAdmin(address(deployerUToken));
    address uTokenAddress = deployerUToken.deploy(utokenParams);
    _aclManager.removeUTokenAdmin(address(deployerUToken));

    vm.stopPrank();
    return uTokenAddress;
  }

  function deploy_protocol() public {
    bytes32 gitCommit = 0;
    DeployProtocol deployerProtocol = new DeployProtocol(
      _admin,
      _adminUpdater,
      address(_aclManager)
    );

    vm.startPrank(_admin);
    address unlockdAddress = deployerProtocol.deploy(gitCommit);
    _unlock = Unlockd(unlockdAddress);

    // Update roles to deploy
    // Add permisions to the protocol
    _aclManager.addPriceUpdater(unlockdAddress);

    // Temporal roles to deploy
    _aclManager.addProtocolAdmin(address(deployerProtocol));
    _aclManager.addGovernanceAdmin(address(deployerProtocol));

    _aclManager.setProtocol(address(_unlock));

    address[] memory listUTokens = new address[](2);
    listUTokens[0] = address(_uTokens['WETH']);
    listUTokens[1] = address(_uTokens['DAI']);

    address[] memory listMarketAdapters = new address[](2);
    listMarketAdapters[0] = _reservoirAdapter;
    listMarketAdapters[1] = _mockAdapter;

    {
      Manager managerImp = new Manager(Constants.MODULEID__MANAGER, 0);
      Action actionImp = new Action(Constants.MODULEID__ACTION, 0);
      Auction auctionImp = new Auction(Constants.MODULEID__AUCTION, 0);
      Market marketImp = new Market(Constants.MODULEID__MARKET, 0);
      BuyNow buyNowImp = new BuyNow(Constants.MODULEID__BUYNOW, 0);
      SellNow sellNowImp = new SellNow(Constants.MODULEID__SELLNOW, 0);
      // Install Modules
      address[] memory modules = new address[](6);
      modules[0] = address(managerImp);
      modules[1] = address(actionImp);
      modules[2] = address(auctionImp);
      modules[3] = address(marketImp);
      modules[4] = address(buyNowImp);
      modules[5] = address(sellNowImp);

      address installer = Unlockd(unlockdAddress).moduleIdToProxy(Constants.MODULEID__INSTALLER);
      Installer(installer).installModules(modules);
    }

    /*** CONFIGURE PROTOCOL */
    {
      address managerAddress = Unlockd(unlockdAddress).moduleIdToProxy(Constants.MODULEID__MANAGER);
      Manager manager = Manager(managerAddress);

      manager.setSigner(_signer);
      manager.setReserveOracle(_reserveOracle);
      manager.setWalletRegistry(_walletRegistry);
      manager.setAllowedControllers(_allowedControllers);

      // Configure UTokens
      uint256 i = 0;
      while (i < listUTokens.length) {
        manager.addUToken(listUTokens[i], true);
        unchecked {
          ++i;
        }
      }

      // Configure Adapters
      uint256 x = 0;
      while (x < listMarketAdapters.length) {
        manager.addMarketAdapters(listMarketAdapters[x], true);
        unchecked {
          ++x;
        }
      }
    }

    // We remove the permision once we deployed everything
    _aclManager.removeProtocolAdmin(address(deployerProtocol));
    _aclManager.removeGovernanceAdmin(address(deployerProtocol));
    vm.stopPrank();
  }

  // Actors ASSETS

  function getActorWithFunds(
    uint256 index,
    string memory asset,
    uint256 amount
  ) public returns (address) {
    address actor = _actors.get(index);
    if (amount == 0) return actor;

    writeTokenBalance(actor, getAssetAddress(asset), amount);

    return actor;
  }

  modifier useAssetActor(uint256 index, uint256 amount) {
    // For now we only have one asset
    vm.startPrank(getActorWithFunds(index, 'WETH', amount));
    _;
    vm.stopPrank();
  }

  function mintNextNFTToken(
    address wallet,
    string memory asset
  ) internal returns (uint256 tokenId) {
    uint256 currentSupply = _nfts.totalSupply(asset);
    tokenId = currentSupply + 1;
    mintNFTToken(wallet, asset, tokenId);
  }

  function mintNFTToken(address wallet, string memory asset, uint256 tokenId) internal {
    _nfts.mintToAddress(wallet, asset, tokenId);
  }

  function createWalletAndMintTokens(uint256 index, string memory asset) internal {
    // We create a wallet for the user
    (address wallet, , , ) = DelegationWalletFactory(_walletFactory).deployFor(
      _actors.get(index),
      address(0)
    );
    uint256 currentSupply = _nfts.totalSupply(asset);

    // Allow collection to this platform
    for (uint256 i = 0; i < currentSupply + 10; ) {
      mintNFTToken(wallet, asset, currentSupply + i);
      unchecked {
        ++i;
      }
    }
  }

  function getAssetAddress(string memory asset) internal view returns (address) {
    if (keccak256(abi.encodePacked(asset)) == keccak256(abi.encodePacked('WETH')))
      return config.weth;
    return _assets.get(asset);
  }

  function getWalletAddress(uint256 index) internal returns (address) {
    DelegationWalletRegistry.Wallet memory wallet = DelegationWalletRegistry(_walletRegistry)
      .getOwnerWalletAt(_actors.get(index), 0);
    return wallet.wallet;
  }

  modifier useActor(uint256 index) {
    vm.startPrank(getActorAddress(index));
    _;
    vm.stopPrank();
  }

  function wasteGas(uint256 slots) internal pure {
    assembly {
      let memPtr := mload(0x40)
      mstore(add(memPtr, mul(32, slots)), 1) // Expand memory
    }
  }

  function addFundToUToken(address uToken, string memory asset, uint256 amount) public {
    uint256 ACTOR = 100;
    address actor = getActorWithFunds(ACTOR, asset, amount);
    vm.startPrank(actor);

    // DEPOSIT
    IERC20(getAssetAddress(asset)).approve(uToken, amount);
    UToken(uToken).deposit(amount, actor, 0);

    vm.stopPrank();
  }

  function sendViaCall(address payable _to, uint value, bytes memory data) public payable {
    // Call returns a boolean value indicating success or failure.
    // This is the current recommended method to use.
    (bool sent, ) = _to.call{value: value}(data);
    require(sent, 'Failed to send Ether');
  }

  function writeTokenBalance(address who, address token, uint256 amt) internal {
    stdstore.target(token).sig(IERC20(token).balanceOf.selector).with_key(who).checked_write(amt);
  }

  // Approve
  function approveAsset(string memory asset, address to, uint256 value) internal {
    IERC20(getAssetAddress(asset)).approve(to, value);
  }

  // Balance
  function balanceOfAsset(string memory asset, address from) internal view returns (uint256) {
    return IERC20(getAssetAddress(asset)).balanceOf(from);
  }

  //************  RESERVOIR DATA ************
  struct ReservoirData {
    uint256 blockNumber;
    address nftAsset;
    uint256 nftTokenId;
    address currency;
    address from;
    address to;
    address approval;
    bytes data;
    bytes approvalData;
    address approvalTo;
    uint256 price;
    uint256 value;
  }

  function _decodeJsonReservoirData(
    string memory path
  ) internal view returns (ReservoirData memory) {
    string memory persistedJson = vm.readFile(path);

    // Transform string to uint
    (uint256 blockNumber, ) = HelperConvert.strToUint(
      abi.decode(persistedJson.parseRaw('.blockNumber'), (string))
    );
    (uint256 value, ) = HelperConvert.strToUint(
      abi.decode(persistedJson.parseRaw('.value'), (string))
    );
    (uint256 nftTokenId, ) = HelperConvert.strToUint(
      abi.decode(persistedJson.parseRaw('.nftTokenId'), (string))
    );

    (uint256 price, ) = HelperConvert.strToUint(
      abi.decode(persistedJson.parseRaw('.price'), (string))
    );

    ReservoirData memory testData = ReservoirData({
      blockNumber: blockNumber,
      nftAsset: abi.decode(persistedJson.parseRaw('.nftAsset'), (address)),
      nftTokenId: nftTokenId,
      from: abi.decode(persistedJson.parseRaw('.from'), (address)),
      to: abi.decode(persistedJson.parseRaw('.to'), (address)),
      data: abi.decode(persistedJson.parseRaw('.data'), (bytes)),
      approvalData: abi.decode(persistedJson.parseRaw('.approvalData'), (bytes)),
      currency: abi.decode(persistedJson.parseRaw('.currency'), (address)),
      approval: abi.decode(persistedJson.parseRaw('.approval'), (address)),
      approvalTo: abi.decode(persistedJson.parseRaw('.approvalTo'), (address)),
      price: price,
      value: value
    });

    return testData;
  }
}
