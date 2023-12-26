// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from 'forge-std/console.sol';
import 'forge-std/StdJson.sol';
import {stdStorage, StdStorage, Test, Vm} from 'forge-std/Test.sol';

import {AssetLogic} from '@unlockd-wallet/src/libs/logic/AssetLogic.sol';
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
import {MaxApyVault} from '@maxapy/MaxApyVault.sol';
import '../../../src/libraries/proxy/UnlockdUpgradeableProxy.sol';
import './../mock/asset/MintableERC20.sol';
import './../mock/adapters/MockAdapter.sol';
import '../../../src/libraries/base/InterestRate.sol';

import '../helpers/HelperNFT.sol'; // solhint-disable-line
import '../helpers/HelperConvert.sol';

import '../base/Base.sol';
import '../base/ActorsBase.sol';
import '../base/NFTBase.sol';

import {Source} from '../mock/chainlink/Source.sol';

import {DeployPeriphery} from '../../../src/deployer/DeployPeriphery.sol';
import {DeployProtocol} from '../../../src/deployer/DeployProtocol.sol';
import {DeployUToken} from '../../../src/deployer/DeployUToken.sol';
import {DeployUTokenConfig} from '../../../src/deployer/DeployUTokenConfig.sol';

import {IUTokenFactory} from '../../../src/interfaces/IUTokenFactory.sol';

import {Constants} from '../../../src/libraries/helpers/Constants.sol';
import {ScaledToken} from '../../../src/libraries/tokens/ScaledToken.sol';
import {Installer} from '../../../src/protocol/modules/Installer.sol';

import {Manager} from '../../../src/protocol/modules/Manager.sol';
import {Action, ActionSign} from '../../../src/protocol/modules/Action.sol';
import {Auction, AuctionSign} from '../../../src/protocol/modules/Auction.sol';
import {BuyNow, BuyNowSign} from '../../../src/protocol/modules/BuyNow.sol';
import {SellNow, SellNowSign} from '../../../src/protocol/modules/SellNow.sol';
import {Market, MarketSign} from '../../../src/protocol/modules/Market.sol';

import {MaxApyStrategy} from '../../../src/protocol/strategies/MaxApy.sol';
import {ReserveOracle, IReserveOracle} from '../../../src/libraries/oracles/ReserveOracle.sol';

import {Unlockd} from '../../../src/protocol/Unlockd.sol';
import {DataTypes} from '../../../src/types/DataTypes.sol';

import {ACLManager} from '../../../src/libraries/configuration/ACLManager.sol';

contract Setup is Base, ActorsBase, NFTBase {
  using stdStorage for StdStorage;
  using stdJson for string;

  receive() external payable {}

  // *************************************
  function setUp() public virtual {
    // By default Mainnet
    this.setUpByChain(1, 0);
  }

  // Define General Setup
  function setUpByChain(uint256 chainId, uint256 blockNumber) public virtual {
    config = Config.getConfig(chainId);

    // Chain FORK
    uint256 chainFork = vm.createFork(
      config.chainName,
      blockNumber == 0 ? config.blockNumber : blockNumber
    );
    vm.selectFork(chainFork);
    // Set timestamp to March 31, 2023 at 00:00 GMT
    vm.warp(1_680_220_800);

    deploy_acl_manager();

    deploy_mocks();

    deploy_wallet();

    deploy_periphery();

    // Deploy strategies
    deploy_strategy(getAssetAddress('WETH'));

    deploy_uTokenFactory();
    // Deploy protocol
    deploy_protocol();
  }

  ///////////////////////////////////////////////////////////////
  // DEPLOYS
  ///////////////////////////////////////////////////////////////

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
    // https://data.chain.link/ethereum/mainnet/stablecoins/dai-usd
    Source daiSource = new Source(8, 100006060);
    // https://data.chain.link/ethereum/mainnet/stablecoins/usdc-usd
    Source usdcSource = new Source(8, 100000000);
    // https://data.chain.link/ethereum/mainnet/crypto-usd/eth-usd
    Source wethSource = new Source(8, 224136576100);

    ReserveOracle(_reserveOracle).addAggregator(makeAsset('WETH'), address(wethSource));
    ReserveOracle(_reserveOracle).addAggregator(makeAsset('USDC'), address(usdcSource));
    ReserveOracle(_reserveOracle).addAggregator(makeAsset('DAI'), address(daiSource));

    vm.stopPrank();
  }

  function deploy_strategy(address underlyingAsset) internal {
    // ONLY FOR SEPOLIA
    uint256 percentageToInvest = 10000; // 50%

    _maxApy = address(
      new MaxApyVault(IERC20(underlyingAsset), 'maxETH', 'MAXETH', makeAddr('treasury'))
    );
    _maxApyStrategy = address(
      new MaxApyStrategy(underlyingAsset, _maxApy, 1 ether, percentageToInvest)
    );
  }

  function deploy_uTokenFactory() public returns (address) {
    vm.startPrank(_admin);

    _uTokenFactory = new UTokenFactory(address(_aclManager), address(new ScaledToken()));

    // Deploy weth pool
    _uTokenFactory.createMarket(
      IUTokenFactory.CreateMarketParams({
        interestRateAddress: address(
          new InterestRate(address(_aclManager), 1 ether, 1 ether, 1 ether, 1 ether)
        ),
        strategyAddress: _maxApyStrategy,
        reserveFactor: 0,
        underlyingAsset: makeAsset('WETH'),
        reserveType: Constants.ReserveType.COMMON,
        decimals: 18,
        tokenName: 'UWeth',
        tokenSymbol: 'UWETH'
      })
    );

    _uTokenFactory.createMarket(
      IUTokenFactory.CreateMarketParams({
        interestRateAddress: address(
          new InterestRate(address(_aclManager), 1 ether, 1 ether, 1 ether, 1 ether)
        ),
        strategyAddress: address(0),
        reserveFactor: 0,
        underlyingAsset: makeAsset('DAI'),
        reserveType: Constants.ReserveType.STABLE,
        decimals: 18,
        tokenName: 'UDAI',
        tokenSymbol: 'UDAI'
      })
    );

    _uTokenFactory.createMarket(
      IUTokenFactory.CreateMarketParams({
        interestRateAddress: address(
          new InterestRate(address(_aclManager), 1 ether, 1 ether, 1 ether, 1 ether)
        ),
        strategyAddress: address(0),
        reserveFactor: 0,
        underlyingAsset: makeAsset('USDC'),
        reserveType: Constants.ReserveType.STABLE,
        decimals: 6,
        tokenName: 'UUSDC',
        tokenSymbol: 'UUSDC'
      })
    );
    vm.stopPrank();
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
    _aclManager.setUTokenFactory(address(_uTokenFactory));

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

  ///////////////////////////////////////////////////////////////
  // ACTOR
  ///////////////////////////////////////////////////////////////

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

  modifier useActor(uint256 index) {
    vm.startPrank(getActorAddress(index));
    _;
    vm.stopPrank();
  }

  ///////////////////////////////////////////////////////////////
  // WALLET
  ///////////////////////////////////////////////////////////////

  function createWalletAndMintTokens(
    address actor,
    string memory asset
  ) internal returns (address, address, address, address) {
    // We create a wallet for the user
    //  return (safeProxy, delegationOwnerProxy, protocolOwnerProxy, guardOwnerProxy);
    (
      address wallet,
      address delegationOwner,
      address protocolOwner,
      address guardOwner
    ) = DelegationWalletFactory(_walletFactory).deployFor(actor, address(0));

    uint256 currentSupply = _nfts.totalSupply(asset);

    // Allow collection to this platform
    for (uint256 i = 0; i < currentSupply + 10; ) {
      mintNFTToken(wallet, asset, currentSupply + i);
      unchecked {
        ++i;
      }
    }
    return (wallet, delegationOwner, protocolOwner, guardOwner);
  }

  function getWalletAddress(address actor) internal view returns (address) {
    DelegationWalletRegistry.Wallet memory wallet = DelegationWalletRegistry(_walletRegistry)
      .getOwnerWalletAt(actor, 0);
    return wallet.wallet;
  }

  function getProtocolOwnerAddress(address actor) internal view returns (address) {
    DelegationWalletRegistry.Wallet memory wallet = DelegationWalletRegistry(_walletRegistry)
      .getOwnerWalletAt(actor, 0);
    return wallet.protocolOwner;
  }

  ///////////////////////////////////////////////////////////////
  // NFTS
  ///////////////////////////////////////////////////////////////

  function mintNFTToken(address wallet, string memory asset, uint256 tokenId) internal {
    _nfts.mintToAddress(wallet, asset, tokenId);
  }

  function mintNextNFTToken(
    address wallet,
    string memory asset
  ) internal returns (uint256 tokenId) {
    uint256 currentSupply = _nfts.totalSupply(asset);
    tokenId = currentSupply + 1;
    mintNFTToken(wallet, asset, tokenId);
  }

  ///////////////////////////////////////////////////////////////
  // ASSETS
  ///////////////////////////////////////////////////////////////
  function _assetsAddress(string memory asset) internal returns (address) {
    if (keccak256(abi.encodePacked(asset)) == keccak256(abi.encodePacked('WETH')))
      return config.weth;
    if (keccak256(abi.encodePacked(asset)) == keccak256(abi.encodePacked('DAI'))) return config.dai;

    if (keccak256(abi.encodePacked(asset)) == keccak256(abi.encodePacked('USDC')))
      return config.usdc;
    // No asset allowed
    return address(0);
  }

  function getAssetAddress(string memory asset) internal returns (address) {
    return _assetsAddress(asset);
  }

  // DEBUG : Remove one of this functions
  function makeAsset(string memory asset) internal returns (address) {
    return _assetsAddress(asset);
  }

  function addFundToUToken(string memory asset, uint256 amount) public {
    address underlyingAsset = getAssetAddress(asset);
    vm.startPrank(makeAddr('funder'));
    // DEPOSIT
    writeTokenBalance(makeAddr('funder'), underlyingAsset, amount);
    IERC20(underlyingAsset).approve(address(_uTokenFactory), amount);
    _uTokenFactory.supply(underlyingAsset, amount, makeAddr('funder'));

    vm.stopPrank();
  }

  ///////////////////////////////////////////////////////////////

  function wasteGas(uint256 slots) internal pure {
    assembly {
      let memPtr := mload(0x40)
      mstore(add(memPtr, mul(32, slots)), 1) // Expand memory
    }
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
  function approveAsset(address asset, address to, uint256 value) internal {
    IERC20(asset).approve(to, value);
  }

  // Balance
  function balanceAssets(address asset, address from) internal view returns (uint256) {
    return IERC20(asset).balanceOf(from);
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

  /////////////////////////////////////////////////////////////////////
  // HELPERS
  /////////////////////////////////////////////////////////////////////
  struct AssetParams {
    bytes32 assetId;
    address collection;
    uint32 tokenId;
    uint128 assetPrice;
    uint256 assetLtv;
  }

  function generate_assets(
    address nftAddress,
    uint256 startCounter,
    uint256 totalArray
  ) internal pure returns (bytes32[] memory, DataTypes.Asset[] memory) {
    // Asesets
    uint256 counter = totalArray - startCounter;
    bytes32[] memory assetsIds = new bytes32[](counter);
    DataTypes.Asset[] memory assets = new DataTypes.Asset[](counter);
    for (uint256 i = 0; i < counter; ) {
      uint32 tokenId = uint32(startCounter + i);
      assetsIds[i] = AssetLogic.assetId(nftAddress, tokenId);
      assets[i] = DataTypes.Asset({collection: nftAddress, tokenId: tokenId});
      unchecked {
        ++i;
      }
    }
    return (assetsIds, assets);
  }

  ///////////////////////////////////////////////////////////////
  // ACTION
  struct AuctionSignParams {
    address user;
    bytes32 loanId;
    uint128 price;
    uint256 totalAssets;
  }

  function auction_signature(
    address action,
    AuctionSignParams memory params,
    AssetParams memory asset
  ) internal view returns (DataTypes.SignAuction memory, DataTypes.EIP712Signature memory) {
    // Get nonce from the user
    uint256 nonce = AuctionSign(action).getNonce(params.user);
    uint40 deadline = uint40(block.timestamp + 1000);

    DataTypes.SignAuction memory data;
    DataTypes.EIP712Signature memory sig;
    {
      // Create the struct
      data = DataTypes.SignAuction({
        loan: DataTypes.SignLoanConfig({
          loanId: params.loanId, // Because is new need to be 0
          aggLoanPrice: params.price,
          aggLtv: 6000,
          aggLiquidationThreshold: 6000,
          totalAssets: uint88(params.totalAssets),
          nonce: nonce,
          deadline: deadline
        }),
        assetId: asset.assetId,
        collection: asset.collection,
        tokenId: asset.tokenId,
        assetPrice: asset.assetPrice,
        assetLtv: 6000,
        endTime: uint40(block.timestamp + 2000),
        nonce: nonce,
        deadline: deadline
      });

      bytes32 digest = AuctionSign(action).calculateDigest(nonce, data);
      (uint8 v, bytes32 r, bytes32 s) = vm.sign(_signerPrivateKey, digest);

      // Build signature struct
      sig = DataTypes.EIP712Signature({v: v, r: r, s: s, deadline: deadline});
    }
    return (data, sig);
  }

  ///////////////////////////////////////////////////////////////
  // AUCTION

  struct ActionSignParams {
    address user;
    bytes32 loanId;
    uint128 price;
    uint256 totalAssets;
    uint256 totalArray;
  }

  function action_signature(
    address action,
    address nftAddress,
    ActionSignParams memory params
  )
    internal
    view
    returns (
      DataTypes.SignAction memory,
      DataTypes.EIP712Signature memory,
      bytes32[] memory,
      DataTypes.Asset[] memory
    )
  {
    // Get nonce from the user
    uint256 nonce = ActionSign(action).getNonce(params.user);
    uint40 deadline = uint40(block.timestamp + 1000);

    // Asesets
    (bytes32[] memory assetsIds, DataTypes.Asset[] memory assets) = generate_assets(
      nftAddress,
      0,
      params.totalArray
    );

    DataTypes.SignAction memory data;
    DataTypes.EIP712Signature memory sig;
    {
      // Create the struct
      data = DataTypes.SignAction({
        loan: DataTypes.SignLoanConfig({
          loanId: params.loanId, // Because is new need to be 0
          aggLoanPrice: params.price,
          aggLtv: 6000,
          aggLiquidationThreshold: 6000,
          totalAssets: uint88(params.totalAssets),
          nonce: nonce,
          deadline: deadline
        }),
        assets: assetsIds,
        underlyingAsset: address(0),
        nonce: nonce,
        deadline: deadline
      });

      bytes32 digest = Action(action).calculateDigest(nonce, data);
      (uint8 v, bytes32 r, bytes32 s) = vm.sign(_signerPrivateKey, digest);

      // Build signature struct
      sig = DataTypes.EIP712Signature({v: v, r: r, s: s, deadline: deadline});
    }
    return (data, sig, assetsIds, assets);
  }

  ///////////////////////////////////////////////////////////////
  // MARKET

  struct MarketSignParams {
    address user;
    bytes32 loanId;
    uint256 price;
    uint256 totalAssets;
  }

  function market_signature(
    address market,
    MarketSignParams memory params,
    AssetParams memory asset
  ) internal view returns (DataTypes.SignMarket memory, DataTypes.EIP712Signature memory) {
    // Get nonce from the user
    uint256 nonce = MarketSign(market).getNonce(params.user);
    uint40 deadline = uint40(block.timestamp + 1000);

    DataTypes.SignMarket memory data;
    DataTypes.EIP712Signature memory sig;
    {
      // Create the struct
      data = DataTypes.SignMarket({
        loan: DataTypes.SignLoanConfig({
          loanId: params.loanId, // Because is new need to be 0
          aggLoanPrice: params.price,
          aggLtv: 6000,
          aggLiquidationThreshold: 6000,
          totalAssets: uint88(params.totalAssets),
          nonce: nonce,
          deadline: deadline
        }),
        assetId: asset.assetId,
        collection: asset.collection,
        tokenId: asset.tokenId,
        assetPrice: asset.assetPrice,
        assetLtv: 6000,
        nonce: nonce,
        deadline: deadline
      });

      bytes32 digest = MarketSign(market).calculateDigest(nonce, data);
      (uint8 v, bytes32 r, bytes32 s) = vm.sign(_signerPrivateKey, digest);

      // Build signature struct
      sig = DataTypes.EIP712Signature({v: v, r: r, s: s, deadline: deadline});
    }
    return (data, sig);
  }

  //////////////////////////////////////////////////////////
  // BORROW
  function borrow_action(
    address action,
    address nft,
    uint256 index,
    uint256 amountToBorrow,
    uint256 price,
    uint256 totalAssets,
    uint256 totalArray
  ) internal returns (bytes32 loanId) {
    vm.startPrank(getActorAddress(index));
    // Get data signed
    (
      DataTypes.SignAction memory signAction,
      DataTypes.EIP712Signature memory sig,
      ,
      DataTypes.Asset[] memory assets
    ) = action_signature(
        action,
        nft,
        ActionSignParams({
          user: getActorAddress(index),
          loanId: 0,
          price: uint128(price),
          totalAssets: totalAssets,
          totalArray: totalArray
        })
      );
    vm.recordLogs();
    // Borrow amount
    Action(action).borrow(amountToBorrow, assets, signAction, sig);
    Vm.Log[] memory entries = vm.getRecordedLogs();
    loanId = bytes32(entries[entries.length - 1].topics[2]);
    vm.stopPrank();
  }

  function borrow_more_action(
    address action,
    address nft,
    bytes32 loanId,
    uint256 index,
    uint256 amountToBorrow,
    uint128 price,
    uint256 totalAssets
  ) internal {
    vm.startPrank(getActorAddress(index));
    // Get data signed
    DataTypes.Asset[] memory assets;
    (
      DataTypes.SignAction memory signAction,
      DataTypes.EIP712Signature memory sig,
      ,

    ) = action_signature(
        action,
        nft,
        ActionSignParams({
          user: getActorAddress(index),
          loanId: loanId,
          price: price,
          totalAssets: totalAssets,
          totalArray: 0
        })
      );

    // Borrow amount
    Action(action).borrow(amountToBorrow, assets, signAction, sig);
    vm.stopPrank();
  }
}
