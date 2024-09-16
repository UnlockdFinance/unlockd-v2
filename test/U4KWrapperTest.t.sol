// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from 'forge-std/console.sol';
import {stdStorage, StdStorage, Test} from 'forge-std/Test.sol';
import './test-utils/setups/Setup.sol';

import {U4K} from '../src/protocol/wrappers/U4K.sol';

import {IUTokenWrapper} from '../src/interfaces/IUTokenWrapper.sol';
import {IERC11554K} from '../src/interfaces/wrappers/IERC11554K.sol';
import {IERC11554KController} from '../src/interfaces/wrappers/IERC11554KController.sol';
import {MockDelegationWalletRegistry} from './test-utils/mock/wrapper/MockDelegationWalletRegistry.sol';
import {ERC1967Proxy} from '@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol';
import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import {IERC1155} from '@openzeppelin/contracts/token/ERC1155/IERC1155.sol';

import {NFTMarket} from './test-utils/mock/market/NFTMarket.sol';

contract U4KWrapperTest is Setup {
  address internal _WETH;

  address internal _sellNow;
  address internal _action;
  address internal _manager;
  // Mainnet
  address _controller = 0xCb4977b21e157d61A8F0f0b7d7973A9eF7462805;

  address _activeCollection = 0x927a51275a610Cd93e23b176670c88157bC48AF2; // tokenId: 42 owner: 0x96152D223763790435a886Db5DEa3aEaA602e904
  address _disabledCollection = 0x207c490D215fd661234F4333dcd4d74D7617e388; // 10

  address _tokenOwner = 0x96152D223763790435a886Db5DEa3aEaA602e904;
  address u4KWrapper;
  NFTMarket internal _market;

  function setUp() public virtual override {
    super.setUpByChain(1, 19419853);
    _market = new NFTMarket();
    _WETH = makeAsset('WETH');

    // Fill the protocol with funds
    addFundToUToken('WETH', 10 ether);
    addFundToUToken('DAI', 10 ether);

    writeTokenBalance(address(_market), makeAsset('WETH'), 100 ether);
    // Create wallet and mint to the safe wallet
    createWalletAndMintTokens(_tokenOwner, 'PUNK');

    _action = _unlock.moduleIdToProxy(Constants.MODULEID__ACTION);
    _sellNow = _unlock.moduleIdToProxy(Constants.MODULEID__SELLNOW);
    _manager = _unlock.moduleIdToProxy(Constants.MODULEID__MANAGER);
    // hoax(_admin);
    // _aclManager.setProtocol(makeAddr('protocol'));

    U4K wrapperImp = new U4K(_activeCollection);
    u4KWrapper = address(
      new ERC1967Proxy(
        address(wrapperImp),
        abi.encodeWithSelector(
          U4K.initialize.selector,
          'Unlockd 4K Wrapper',
          'U4KW',
          address(_aclManager),
          _controller
        )
      )
    );
  }

  /////////////////////////////////////////////////////////////////////////////////
  // SELLNOW
  /////////////////////////////////////////////////////////////////////////////////

  struct LoanData {
    bytes32 loanId;
    uint256 aggLoanPrice;
    uint88 totalAssets;
  }

  function _generate_signature(
    address sender,
    bytes32 assetId,
    LoanData memory loanData,
    ReservoirData memory dataSellWETHCurrency
  ) internal view returns (DataTypes.SignSellNow memory, DataTypes.EIP712Signature memory) {
    // Get nonce from the user
    uint256 nonce = SellNowSign(_sellNow).getNonce(sender);
    uint256 deadline = block.timestamp + 1000;

    DataTypes.SignSellNow memory data;
    DataTypes.EIP712Signature memory sig;
    {
      // Create the struct
      data = DataTypes.SignSellNow({
        loan: DataTypes.SignLoanConfig({
          loanId: loanData.loanId, // Because is new need to be 0
          aggLoanPrice: loanData.aggLoanPrice,
          aggLtv: 6000,
          aggLiquidationThreshold: 6000,
          totalAssets: loanData.totalAssets,
          nonce: nonce,
          deadline: deadline
        }),
        assetId: assetId,
        marketAdapter: address(_wrapperAdapter),
        marketApproval: dataSellWETHCurrency.approvalTo,
        marketPrice: dataSellWETHCurrency.price,
        underlyingAsset: config.weth,
        from: dataSellWETHCurrency.from,
        to: dataSellWETHCurrency.to,
        data: dataSellWETHCurrency.data,
        value: dataSellWETHCurrency.value,
        nonce: nonce,
        deadline: deadline
      });

      bytes32 digest = SellNow(_sellNow).calculateDigest(nonce, data);
      (uint8 v, bytes32 r, bytes32 s) = vm.sign(_signerPrivateKey, digest);

      // Build signature struct
      sig = DataTypes.EIP712Signature({v: v, r: r, s: s, deadline: deadline});
    }
    return (data, sig);
  }

  /////////////////////////////////////////////////////////////////////////////////
  // WRAP
  /////////////////////////////////////////////////////////////////////////////////

  function test_wrapp() external {
    hoax(_tokenOwner);
    IERC1155(_activeCollection).setApprovalForAll(u4KWrapper, true);
    hoax(_tokenOwner);
    IUTokenWrapper(u4KWrapper).mint(makeAddr('abwallet'), 42);
  }

  function test_wrapp_sending() external {
    hoax(_tokenOwner);
    IERC1155(_activeCollection).safeTransferFrom(
      _tokenOwner,
      u4KWrapper,
      42,
      1,
      abi.encode(_tokenOwner)
    );
  }

  function test_unwrapp() external {
    hoax(_tokenOwner);
    IERC1155(_activeCollection).setApprovalForAll(u4KWrapper, true);

    hoax(_tokenOwner);
    IUTokenWrapper(u4KWrapper).mint(makeAddr('abwallet'), 42);
    assertEq(IERC1155(_activeCollection).balanceOf(_tokenOwner, 42), 0);

    hoax(makeAddr('abwallet'));
    IUTokenWrapper(u4KWrapper).burn(1);

    assertEq(IERC1155(_activeCollection).balanceOf(makeAddr('abwallet'), 42), 1);
  }

  function test_sell_wrappedAsset() external {
    // Preparing data to execute
    address walletAddress = getWalletAddress(_tokenOwner);
    vm.startPrank(_tokenOwner);
    // PREPARE THE TOKEN
    IERC1155(_activeCollection).setApprovalForAll(u4KWrapper, true);
    IUTokenWrapper(u4KWrapper).mint(walletAddress, 42);
    vm.stopPrank();

    DataTypes.Asset memory asset = DataTypes.Asset({collection: address(u4KWrapper), tokenId: 1});

    vm.assume(IERC20(makeAsset('WETH')).balanceOf(_tokenOwner) == 0);
    vm.assume(IERC721(asset.collection).ownerOf(asset.tokenId) == walletAddress);

    (DataTypes.SignSellNow memory data, DataTypes.EIP712Signature memory sig) = _generate_signature(
      _tokenOwner,
      AssetLogic.assetId(asset.collection, asset.tokenId),
      LoanData({loanId: 0x0, aggLoanPrice: 0, totalAssets: 0}),
      ReservoirData({
        blockNumber: block.number,
        nftAsset: asset.collection,
        nftTokenId: asset.tokenId,
        currency: _WETH,
        from: walletAddress,
        to: address(_market),
        approval: address(_market),
        approvalTo: address(_market),
        approvalData: '0x',
        data: abi.encodeWithSelector(
          NFTMarket.sell.selector,
          _activeCollection,
          42,
          _WETH,
          1 ether
        ),
        price: 1 ether,
        value: 0
      })
    );
    hoax(_tokenOwner);
    SellNow(_sellNow).sell(asset, data, sig);
    assertEq(IERC20(_WETH).balanceOf(_tokenOwner), 1 ether);
    assertEq(IERC1155(_activeCollection).balanceOf(address(_market), 42), 1);
  }

  function test_sellnow_sell_repay_loan_banana() public {
    // Preparing data to execute
    address walletAddress = getWalletAddress(_tokenOwner);
    hoax(_admin);
    Manager(_manager).allowCollectionReserveType(u4KWrapper, Constants.ReserveType.ALL);

    vm.startPrank(_tokenOwner);
    // PREPARE THE TOKEN
    IERC1155(_activeCollection).setApprovalForAll(u4KWrapper, true);
    IUTokenWrapper(u4KWrapper).mint(walletAddress, 42);
    vm.stopPrank();

    DataTypes.Asset[] memory asset = new DataTypes.Asset[](1);
    asset[0] = DataTypes.Asset({collection: address(u4KWrapper), tokenId: 1});
    uint40 deadline = uint40(block.timestamp + 1000);

    DataTypes.SignAction memory actionData;
    DataTypes.EIP712Signature memory actionSig;
    {
      bytes32[] memory assetIds = new bytes32[](1);
      assetIds[0] = AssetLogic.assetId(asset[0].collection, asset[0].tokenId);
      uint256 nonce = ActionSign(_action).getNonce(_tokenOwner);
      // Create the struct
      actionData = DataTypes.SignAction({
        loan: DataTypes.SignLoanConfig({
          loanId: 0, // Because is new need to be 0
          aggLoanPrice: uint128(2 ether),
          aggLtv: 6000,
          aggLiquidationThreshold: 7000,
          totalAssets: uint88(1),
          nonce: nonce,
          deadline: deadline
        }),
        assets: assetIds,
        underlyingAsset: _WETH,
        nonce: nonce,
        deadline: deadline
      });

      bytes32 digest = Action(_action).calculateDigest(nonce, actionData);
      (uint8 v, bytes32 r, bytes32 s) = vm.sign(_signerPrivateKey, digest);

      // Build signature struct
      actionSig = DataTypes.EIP712Signature({v: v, r: r, s: s, deadline: deadline});
    }
    vm.assume(IERC20(makeAsset('WETH')).balanceOf(_tokenOwner) == 0);
    vm.assume(IERC721(asset[0].collection).ownerOf(asset[0].tokenId) == walletAddress);

    vm.startPrank(_tokenOwner);
    vm.recordLogs();

    Action(_action).borrow(0.2 ether, asset, actionData, actionSig);
    Vm.Log[] memory entries = vm.getRecordedLogs();
    bytes32 loanId = bytes32(entries[entries.length - 1].topics[2]);

    vm.stopPrank();

    (DataTypes.SignSellNow memory data, DataTypes.EIP712Signature memory sig) = _generate_signature(
      _tokenOwner,
      AssetLogic.assetId(asset[0].collection, asset[0].tokenId),
      LoanData({loanId: loanId, aggLoanPrice: 0, totalAssets: 0}),
      ReservoirData({
        blockNumber: block.number,
        nftAsset: asset[0].collection,
        nftTokenId: asset[0].tokenId,
        currency: _WETH,
        from: walletAddress,
        to: address(_market),
        approval: address(_market),
        approvalTo: address(_market),
        approvalData: '0x',
        data: abi.encodeWithSelector(
          NFTMarket.sell.selector,
          _activeCollection,
          42,
          _WETH,
          1 ether
        ),
        price: 1 ether,
        value: 0
      })
    );
    hoax(_tokenOwner);
    SellNow(_sellNow).sell(asset[0], data, sig);

    assertEq(IERC1155(_activeCollection).balanceOf(address(_market), 42), 1);
  }
}
