// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;
import {stdStorage, StdStorage, Test} from 'forge-std/Test.sol';

import '../test-utils/setups/Setup.sol';

import '@openzeppelin/contracts/utils/cryptography/ECDSA.sol';
import {AssetLogic} from '@unlockd-wallet/src/libs/logic/AssetLogic.sol';
import {Action, ActionSign} from '../../src/protocol/modules/Action.sol';
import {BaseCoreModule} from '../../src/libraries/base/BaseCoreModule.sol';
import {Errors} from '../../src/libraries/helpers/Errors.sol';

contract ActionSignSeam is ActionSign {
  constructor(address signer) {
    _signer = signer;
  }

  function validate(
    address msgSender,
    DataTypes.SignAction calldata signAction,
    DataTypes.EIP712Signature calldata sig
  ) public {
    _validateSignature(msgSender, signAction, sig);
  }

  function removeSigner() public {
    _signer = address(0);
  }
}

contract ActionSignTest is Setup {
  address internal _nft;
  address internal _seam;

  uint256 internal ACTOR = 1;

  function setUp() public virtual override {
    super.setUp();

    _seam = address(new ActionSignSeam(_signer));
  }

  function test_valid_signature() public {
    uint256 nonce = ActionSignSeam(_seam).getNonce(super.getActorAddress(ACTOR));
    uint40 deadline = uint40(block.timestamp + 1000);
    DataTypes.SignAction memory data = buildData(nonce, deadline);

    bytes32 digest = ActionSignSeam(_seam).calculateDigest(nonce, data);
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
    ActionSignSeam(_seam).validate(msgSender, data, sig);
    vm.stopPrank();
  }

  function test_orphan_signature() public {
    uint256 nonce = ActionSignSeam(_seam).getNonce(super.getActorAddress(ACTOR));
    uint40 deadline = uint40(block.timestamp + 1000);
    DataTypes.SignAction memory data = buildData(nonce, deadline);

    bytes32 digest = ActionSignSeam(_seam).calculateDigest(nonce, data);
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
    ActionSignSeam(_seam).validate(msgSender, data, sig);
    vm.stopPrank();
  }

  function test_signature_without_signer() public {
    uint256 nonce = ActionSignSeam(_seam).getNonce(super.getActorAddress(ACTOR));
    uint40 deadline = uint40(block.timestamp + 1000);
    DataTypes.SignAction memory data = buildData(nonce, deadline);

    bytes32 digest = ActionSignSeam(_seam).calculateDigest(nonce, data);
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(_signerPrivateKey, digest);
    // Build signature struct
    DataTypes.EIP712Signature memory sig = DataTypes.EIP712Signature({
      v: v,
      r: r,
      s: s,
      deadline: deadline
    });

    address msgSender = super.getActorAddress(ACTOR);
    ActionSignSeam(_seam).removeSigner();
    // We validate the signature
    vm.startPrank(super.getActorAddress(ACTOR));
    vm.expectRevert(abi.encodeWithSelector(Errors.InvalidRecoveredAddress.selector));
    ActionSignSeam(_seam).validate(msgSender, data, sig);
    vm.stopPrank();
  }

  function test_invalid_deadline_signature() public {
    uint256 nonce = ActionSignSeam(_seam).getNonce(super.getActorAddress(ACTOR));
    uint40 deadline = uint40(block.timestamp - 1000);
    DataTypes.SignAction memory data = buildData(nonce, deadline);

    vm.expectRevert(Errors.TimestampExpired.selector);
    ActionSignSeam(_seam).calculateDigest(nonce, data);
  }

  function test_invalid_signature() public {
    uint256 nonce = ActionSignSeam(_seam).getNonce(super.getActorAddress(ACTOR));
    uint40 deadline = uint40(block.timestamp + 1000);
    DataTypes.SignAction memory data = buildData(nonce, deadline + 10);

    bytes32 digest = ActionSignSeam(_seam).calculateDigest(nonce, data);
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
    ActionSignSeam(_seam).validate(msgSender, data, sig);
    vm.stopPrank();
  }

  function test_invalid_signer() public {
    uint256 nonce = ActionSignSeam(_seam).getNonce(super.getActorAddress(ACTOR));
    uint40 deadline = uint40(block.timestamp + 1000);
    DataTypes.SignAction memory data = buildData(nonce, deadline);

    bytes32 digest = ActionSign(_seam).calculateDigest(nonce, data);
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
    ActionSignSeam(_seam).validate(msgSender, data, sig);
    vm.stopPrank();
  }

  function test_invalid_nonce() public {
    uint40 deadline = uint40(block.timestamp + 1000);
    (
      DataTypes.EIP712Signature memory sig,
      DataTypes.SignAction memory data
    ) = buildSignatureAndData(deadline);

    address msgSender = super.getActorAddress(ACTOR);
    // We validate the signature
    vm.startPrank(super.getActorAddress(ACTOR));
    ActionSignSeam(_seam).validate(msgSender, data, sig);
    vm.expectRevert(abi.encodeWithSelector(Errors.InvalidRecoveredAddress.selector));
    ActionSignSeam(_seam).validate(msgSender, data, sig);
    vm.stopPrank();

    (
      DataTypes.EIP712Signature memory sig_tow,
      DataTypes.SignAction memory data_two
    ) = buildSignatureAndData(deadline);

    vm.startPrank(super.getActorAddress(ACTOR));
    ActionSignSeam(_seam).validate(msgSender, data_two, sig_tow);
    vm.stopPrank();
  }

  function buildSignatureAndData(
    uint256 deadline
  ) private view returns (DataTypes.EIP712Signature memory, DataTypes.SignAction memory) {
    uint256 nonce = ActionSignSeam(_seam).getNonce(super.getActorAddress(ACTOR));

    DataTypes.SignAction memory data = buildData(nonce, deadline);

    bytes32 digest = ActionSign(_seam).calculateDigest(nonce, data);
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
  ) private view returns (DataTypes.SignAction memory) {
    bytes32[] memory assets = new bytes32[](2);

    for (uint256 i = 0; i < 2; ) {
      assets[i] = AssetLogic.assetId(_nft, i + 1);
      unchecked {
        ++i;
      }
    }

    // Create the struct
    return
      DataTypes.SignAction({
        loan: DataTypes.SignLoanConfig({
          loanId: 0, // Because is new need to be 0
          aggLoanPrice: 1 ether,
          aggLtv: 60000,
          aggLiquidationThreshold: 60000,
          totalAssets: 2,
          nonce: nonce,
          deadline: deadline
        }),
        assets: assets,
        underlyingAsset: address(0),
        nonce: nonce,
        deadline: deadline
      });
  }
}
