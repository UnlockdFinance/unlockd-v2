// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import '../test-utils/setups/Setup.sol';
import {BuyNow, BuyNowSign} from '../../src/protocol/modules/BuyNow.sol';
import {AssetLogic} from '@unlockd-wallet/src/libs/logic/AssetLogic.sol';
import {stdStorage, StdStorage, Test} from 'forge-std/Test.sol';
import {BaseCoreModule} from '../../src/libraries/base/BaseCoreModule.sol';
import '@openzeppelin/contracts/utils/cryptography/ECDSA.sol';
import {Errors} from '../../src/libraries/helpers/Errors.sol';

contract SignSeam is BuyNowSign {
  DataTypes.SignBuyNow internal data;

  constructor(address signer) {
    _signer = signer;
  }

  function validate(
    address msgSender,
    DataTypes.SignBuyNow calldata signBuyNow,
    DataTypes.EIP712Signature calldata sig
  ) public {
    _validateSignature(msgSender, signBuyNow, sig);
  }

  function removeSigner() public {
    _signer = address(0);
  }
}

contract BuyNowSignTest is Setup {
  address internal _nft;
  address internal _seam;
  uint256 internal ACTOR = 1;
  ReservoirData dataETHCurrency;

  function setUp() public virtual override {
    super.setUp();

    _seam = address(new SignSeam(_signer));
    // ETH TEST
    dataETHCurrency = _decodeJsonReservoirData(
      './exec/buy_test_data_0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2.json'
    );
  }

  function test_valid_signature() public {
    uint256 nonce = SignSeam(_seam).getNonce(super.getActorAddress(ACTOR));
    uint40 deadline = uint40(block.timestamp + 1000);
    DataTypes.SignBuyNow memory data = buildData(nonce, deadline);

    bytes32 digest = SignSeam(_seam).calculateDigest(nonce, data);
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(_signerPrivateKey, digest);
    // Build signature struct
    DataTypes.EIP712Signature memory sig = DataTypes.EIP712Signature({
      v: v,
      r: r,
      s: s,
      deadline: deadline
    });

    address msgSender = super.getActorAddress(ACTOR);
    // We validate the signature
    vm.startPrank(super.getActorAddress(ACTOR));
    SignSeam(_seam).validate(msgSender, data, sig);
    vm.stopPrank();
  }

  function test_orphan_signature() public {
    uint256 nonce = SignSeam(_seam).getNonce(super.getActorAddress(ACTOR));
    uint40 deadline = uint40(block.timestamp + 1000);
    DataTypes.SignBuyNow memory data = buildData(nonce, deadline);

    bytes32 digest = SignSeam(_seam).calculateDigest(nonce, data);
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(_signerPrivateKey, digest);
    // Build signature struct
    DataTypes.EIP712Signature memory sig = DataTypes.EIP712Signature({
      v: v,
      r: r,
      s: s,
      deadline: deadline
    });

    address msgSender = address(0);
    // We validate the signature
    vm.startPrank(super.getActorAddress(ACTOR));
    vm.expectRevert(abi.encodeWithSelector(Errors.SenderZeroAddress.selector));
    SignSeam(_seam).validate(msgSender, data, sig);
    vm.stopPrank();
  }

  function test_signature_without_signer() public {
    uint256 nonce = SignSeam(_seam).getNonce(super.getActorAddress(ACTOR));
    uint40 deadline = uint40(block.timestamp + 1000);
    DataTypes.SignBuyNow memory data = buildData(nonce, deadline);

    bytes32 digest = SignSeam(_seam).calculateDigest(nonce, data);
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(_signerPrivateKey, digest);
    // Build signature struct
    DataTypes.EIP712Signature memory sig = DataTypes.EIP712Signature({
      v: v,
      r: r,
      s: s,
      deadline: deadline
    });

    address msgSender = super.getActorAddress(ACTOR);
    SignSeam(_seam).removeSigner();
    // We validate the signature
    vm.startPrank(super.getActorAddress(ACTOR));
    vm.expectRevert(abi.encodeWithSelector(Errors.InvalidRecoveredAddress.selector));
    SignSeam(_seam).validate(msgSender, data, sig);
    vm.stopPrank();
  }

  function test_invalid_deadline_signature() public {
    uint256 nonce = SignSeam(_seam).getNonce(super.getActorAddress(ACTOR));
    uint40 deadline = uint40(block.timestamp - 1000);
    DataTypes.SignBuyNow memory data = buildData(nonce, deadline);

    vm.expectRevert(Errors.TimestampExpired.selector);
    SignSeam(_seam).calculateDigest(nonce, data);
  }

  function test_invalid_signature() public {
    uint256 nonce = SignSeam(_seam).getNonce(super.getActorAddress(ACTOR));
    uint40 deadline = uint40(block.timestamp + 1000);
    DataTypes.SignBuyNow memory data = buildData(nonce, deadline + 10);

    bytes32 digest = SignSeam(_seam).calculateDigest(nonce, data);
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(_signerPrivateKey, digest);
    // Build signature struct
    DataTypes.EIP712Signature memory sig = DataTypes.EIP712Signature({
      v: v,
      r: r,
      s: s,
      deadline: deadline
    });

    address msgSender = super.getActorAddress(ACTOR);
    // We validate the signature
    vm.startPrank(super.getActorAddress(ACTOR));
    vm.expectRevert(abi.encodeWithSelector(Errors.NotEqualDeadline.selector));
    SignSeam(_seam).validate(msgSender, data, sig);
    vm.stopPrank();
  }

  function test_invalid_signer() public {
    uint256 nonce = SignSeam(_seam).getNonce(super.getActorAddress(ACTOR));
    uint40 deadline = uint40(block.timestamp + 1000);
    DataTypes.SignBuyNow memory data = buildData(nonce, deadline);

    bytes32 digest = BuyNowSign(_seam).calculateDigest(nonce, data);
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(_adminPK, digest);
    // Build signature struct
    DataTypes.EIP712Signature memory sig = DataTypes.EIP712Signature({
      v: v,
      r: r,
      s: s,
      deadline: deadline
    });

    address msgSender = super.getActorAddress(ACTOR);
    // We validate the signature
    vm.startPrank(super.getActorAddress(ACTOR));
    vm.expectRevert(abi.encodeWithSelector(Errors.InvalidRecoveredAddress.selector));
    SignSeam(_seam).validate(msgSender, data, sig);
    vm.stopPrank();
  }

  function test_invalid_nonce() public {
    uint40 deadline = uint40(block.timestamp + 1000);
    (
      DataTypes.EIP712Signature memory sig,
      DataTypes.SignBuyNow memory data
    ) = buildSignatureAndData(deadline);

    address msgSender = super.getActorAddress(ACTOR);
    // We validate the signature
    vm.startPrank(super.getActorAddress(ACTOR));
    SignSeam(_seam).validate(msgSender, data, sig);
    vm.expectRevert(abi.encodeWithSelector(Errors.WrongNonce.selector));
    SignSeam(_seam).validate(msgSender, data, sig);
    vm.stopPrank();

    (
      DataTypes.EIP712Signature memory sig_tow,
      DataTypes.SignBuyNow memory data_two
    ) = buildSignatureAndData(deadline);

    vm.startPrank(super.getActorAddress(ACTOR));
    SignSeam(_seam).validate(msgSender, data_two, sig_tow);
    vm.stopPrank();
  }

  function buildSignatureAndData(
    uint256 deadline
  ) private view returns (DataTypes.EIP712Signature memory, DataTypes.SignBuyNow memory) {
    uint256 nonce = SignSeam(_seam).getNonce(super.getActorAddress(ACTOR));

    DataTypes.SignBuyNow memory data = buildData(nonce, deadline);

    bytes32 digest = SignSeam(_seam).calculateDigest(nonce, data);
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(_signerPrivateKey, digest);
    // Build signature struct
    DataTypes.EIP712Signature memory sig = DataTypes.EIP712Signature({
      v: v,
      r: r,
      s: s,
      deadline: deadline
    });
    return (sig, data);
  }

  function buildData(
    uint256 nonce,
    uint256 deadline
  ) private view returns (DataTypes.SignBuyNow memory) {
    return
      DataTypes.SignBuyNow({
        asset: DataTypes.SignAsset({
          assetId: AssetLogic.assetId(dataETHCurrency.nftAsset, dataETHCurrency.nftTokenId),
          collection: dataETHCurrency.nftAsset,
          tokenId: dataETHCurrency.nftTokenId,
          price: dataETHCurrency.price,
          nonce: nonce,
          deadline: deadline
        }),
        marketAdapter: address(0),
        assetLtv: 6000,
        assetLiquidationThreshold: 6000,
        data: dataETHCurrency.data,
        value: dataETHCurrency.value,
        from: dataETHCurrency.from,
        to: super.getActorAddress(ACTOR),
        marketApproval: dataETHCurrency.approval,
        underlyingAsset: dataETHCurrency.currency,
        marketPrice: dataETHCurrency.price,
        nonce: nonce,
        deadline: deadline
      });
  }
}
