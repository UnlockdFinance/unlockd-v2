// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import '../test-utils/setups/Setup.sol';
import {Auction, AuctionSign} from '../../src/protocol/modules/Auction.sol';
import {AssetLogic} from '@unlockd-wallet/src/libs/logic/AssetLogic.sol';
import {stdStorage, StdStorage, Test} from 'forge-std/Test.sol';
import {BaseCoreModule} from '../../src/libraries/base/BaseCoreModule.sol';
import '@openzeppelin/contracts/utils/cryptography/ECDSA.sol';
import {Errors} from '../../src/libraries/helpers/Errors.sol';

contract SignSeam is AuctionSign {
  DataTypes.SignAuction internal data;

  constructor(address signer) {
    _signer = signer;
  }

  function validate(
    address msgSender,
    DataTypes.SignAuction calldata signAuction,
    DataTypes.EIP712Signature calldata sig
  ) public {
    _validateSignature(msgSender, signAuction, sig);
  }

  function removeSigner() public {
    _signer = address(0);
  }
}

contract AuctionSignTest is Setup {
  address internal _nft;
  address internal _seam;
  uint256 internal ACTOR = 1;

  function setUp() public virtual override {
    super.setUp();

    _seam = address(new SignSeam(_signer));
  }

  function test_valid_signature() public {
    uint256 nonce = SignSeam(_seam).getNonce(super.getActorAddress(ACTOR));
    uint40 deadline = uint40(block.timestamp + 1000);
    DataTypes.SignAuction memory data = buildData(nonce, deadline);

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
    DataTypes.SignAuction memory data = buildData(nonce, deadline);

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
    DataTypes.SignAuction memory data = buildData(nonce, deadline);

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
    DataTypes.SignAuction memory data = buildData(nonce, deadline);

    vm.expectRevert(Errors.TimestampExpired.selector);
    SignSeam(_seam).calculateDigest(nonce, data);
  }

  function test_invalid_signature() public {
    uint256 nonce = SignSeam(_seam).getNonce(super.getActorAddress(ACTOR));
    uint40 deadline = uint40(block.timestamp + 1000);
    DataTypes.SignAuction memory data = buildData(nonce, deadline + 10);

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
    DataTypes.SignAuction memory data = buildData(nonce, deadline);

    bytes32 digest = AuctionSign(_seam).calculateDigest(nonce, data);
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
      DataTypes.SignAuction memory data
    ) = buildSignatureAndData(deadline);

    address msgSender = super.getActorAddress(ACTOR);
    // We validate the signature
    vm.startPrank(super.getActorAddress(ACTOR));
    SignSeam(_seam).validate(msgSender, data, sig);
    vm.expectRevert(abi.encodeWithSelector(Errors.InvalidRecoveredAddress.selector));
    SignSeam(_seam).validate(msgSender, data, sig);
    vm.stopPrank();

    (
      DataTypes.EIP712Signature memory sig_tow,
      DataTypes.SignAuction memory data_two
    ) = buildSignatureAndData(deadline);

    vm.startPrank(super.getActorAddress(ACTOR));
    SignSeam(_seam).validate(msgSender, data_two, sig_tow);
    vm.stopPrank();
  }

  function buildSignatureAndData(
    uint256 deadline
  ) private returns (DataTypes.EIP712Signature memory, DataTypes.SignAuction memory) {
    uint256 nonce = SignSeam(_seam).getNonce(super.getActorAddress(ACTOR));

    DataTypes.SignAuction memory data = buildData(nonce, deadline);

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
  ) private view returns (DataTypes.SignAuction memory) {
    bytes32[] memory assets = new bytes32[](2);

    for (uint256 i = 0; i < 2; ) {
      assets[i] = AssetLogic.assetId(_nft, i + 1);
      unchecked {
        ++i;
      }
    }

    // Create the struct
    return
      DataTypes.SignAuction({
        loan: DataTypes.SignLoanConfig({
          loanId: 0, // Because is new need to be 0
          aggLoanPrice: 1 ether,
          aggLtv: 60000,
          aggLiquidationThreshold: 60000,
          totalAssets: 2,
          nonce: nonce,
          deadline: deadline
        }),
        assetId: AssetLogic.assetId(_nft, 1),
        collection: _nft,
        tokenId: 1,
        assetPrice: 0.5 ether,
        assetLtv: 60000,
        endTime: uint40(block.timestamp + 1 days),
        nonce: nonce,
        deadline: deadline
      });
  }
}
