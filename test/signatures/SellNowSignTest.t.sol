// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;
import '../test-utils/setups/Setup.sol';
import {SellNow, SellNowSign} from '../../src/protocol/modules/SellNow.sol';
import {AssetLogic} from '@unlockd-wallet/src/libs/logic/AssetLogic.sol';
import {BaseCoreModule} from '../../src/libraries/base/BaseCoreModule.sol';
import '@openzeppelin/contracts/utils/cryptography/ECDSA.sol';
import {Errors} from '../../src/libraries/helpers/Errors.sol';

contract SignSeam is SellNowSign {
  constructor(address signer) {
    _signer = signer;
  }

  function validate(
    address msgSender,
    DataTypes.SignSellNow calldata sellnow,
    DataTypes.EIP712Signature calldata sig
  ) public {
    _validateSignature(msgSender, sellnow, sig);
  }

  function removeSigner() public {
    _signer = address(0);
  }
}

contract SellNowSignTest is Setup {
  address internal _nft;
  address internal _seam;
  uint256 internal ACTOR = 1;

  function setUp() public virtual override {
    super.setUp();

    _seam = address(new SignSeam(_signer));
    // ETH TEST
  }

  function test_valid_signature() public {
    uint256 nonce = SignSeam(_seam).getNonce(super.getActorAddress(ACTOR));
    uint40 deadline = uint40(block.timestamp + 1000);
    DataTypes.SignSellNow memory data = buildData(nonce, deadline);

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
    DataTypes.SignSellNow memory data = buildData(nonce, deadline);

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
    DataTypes.SignSellNow memory data = buildData(nonce, deadline);

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
    DataTypes.SignSellNow memory data = buildData(nonce, deadline);

    vm.expectRevert(Errors.TimestampExpired.selector);
    SignSeam(_seam).calculateDigest(nonce, data);
  }

  function test_invalid_signature() public {
    uint256 nonce = SignSeam(_seam).getNonce(super.getActorAddress(ACTOR));
    uint40 deadline = uint40(block.timestamp + 1000);
    DataTypes.SignSellNow memory data = buildData(nonce, deadline + 10);

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
    DataTypes.SignSellNow memory data = buildData(nonce, deadline);

    bytes32 digest = SellNowSign(_seam).calculateDigest(nonce, data);
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
      DataTypes.SignSellNow memory data
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
      DataTypes.SignSellNow memory data_two
    ) = buildSignatureAndData(deadline);

    vm.startPrank(super.getActorAddress(ACTOR));
    SignSeam(_seam).validate(msgSender, data_two, sig_tow);
    vm.stopPrank();
  }

  function buildSignatureAndData(
    uint256 deadline
  ) private returns (DataTypes.EIP712Signature memory, DataTypes.SignSellNow memory) {
    uint256 nonce = SignSeam(_seam).getNonce(super.getActorAddress(ACTOR));

    DataTypes.SignSellNow memory data = buildData(nonce, deadline);

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
  ) private pure returns (DataTypes.SignSellNow memory) {
    return
      DataTypes.SignSellNow({
        loan: DataTypes.SignLoanConfig({
          loanId: 0, // Because is new need to be 0
          aggLoanPrice: 1 ether,
          aggLtv: 60000,
          aggLiquidationThreshold: 60000,
          totalAssets: 2,
          nonce: nonce,
          deadline: deadline
        }),
        // asset: DataTypes.SignAsset({
        //   assetId: AssetLogic.assetId(_nft, 1),
        //   collection: _nft,
        //   tokenId: 1,
        //   price: 0.5 ether,
        //   nonce: nonce,
        //   deadline: deadline
        // }),
        marketApproval: address(0),
        marketPrice: 1 ether,
        underlyingAsset: address(0),
        from: address(0),
        to: address(0),
        data: 'DATA',
        value: uint256(0),
        nonce: nonce,
        deadline: deadline
      });
  }
}
