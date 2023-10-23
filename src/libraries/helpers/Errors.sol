// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

/**
 * @title Errors library
 * @author Unlockd
 * @notice Defines the error messages emitted by the different contracts of the Unlockd protocol
 */
library Errors {
  ///////////////////////////////////////////
  ///   GENERIC
  ///////////////////////////////////////////

  error AccessDenied(string paramName);
  //error ZeroAddress(string paramName);

  error InvalidParam(string paramName);
  error ArrayLengthMismatch(string details);
  error InvalidArrayLength();
  error Paused();
  error Frozen();

  error AddressesNotEquals();
  error NumbersNotEquals();

  error ZeroAddress();
  error ZeroBytes();
  error ZeroNumber();

  error ACLAdminZeroAddress();

  error UTokenNotAllowed();
  error AdapterNotAllowed();
  error TimestampExpired();
  error TimestampNotExpired();
  error NotImplemented();

  error InvalidParams();
  error InvalidModule();
  error InvalidCurrentLtv();
  error InvalidTotalAmount();
  error InvalidCurrentLiquidationThreshold();
  error InvalidUserCollateralBalance();
  error InvalidOrderOwner();
  error InvalidOrderBuyer();

  error InvalidLoanOwner();
  error InvalidUToken();

  error InvalidEndAmount();
  error InvalidStartAmount();
  error InvalidEndTime();
  error InvalidStartTime();

  error InvalidPriceFeedKey();
  error InvalidAggregator();

  error NotEnoughLiquidity();
  error AmountExceedsDebt();
  error AmountExceedsBalance();
  error AmountToLow();
  error CollectionNotAllowed();
  error NotAssetOwner();
  error UnsuccessfulExecution();

  error InvalidRecoveredAddress();
  error SenderZeroAddress();

  error NotEqualDeadline();
  error NotEqualUnderlyingAsset();
  error NotEqualTotalAssets();
  error NotEqualOrderOwner();
  error NotEqualSender();

  error ProtocolAccessDenied();
  error UTokenAccessDenied();
  error GovernanceAccessDenied();
  error EmergencyAccessDenied();
  error RoleAccessDenied();

  ///////////////////////////////////////////
  ///   ROUTER
  ///////////////////////////////////////////

  error BaseInputToShort();
  error ReentrancyLocked();
  error RevertEmptyBytes();
  ///////////////////////////////////////////
  ///   WALLET
  ///////////////////////////////////////////

  error UnlockdWalletNotFound();
  error InvalidWalletOwner();
  error NotEqualWallet();
  error DelegationOwnerZeroAddress();

  ///////////////////////////////////////////
  ///   LOAN
  ///////////////////////////////////////////

  error HealtyLoan();
  error UnhealtyLoan();
  error UnableToBorrowMore();
  error LoanNotActive();
  error LowCollateral();
  error InvalidLoanId();

  ///////////////////////////////////////////
  ///   ORDER
  ///////////////////////////////////////////

  error OrderNotAllowed();
  error InvalidOrderId();

  ///////////////////////////////////////////
  ///   ASSETS
  ///////////////////////////////////////////

  error InvalidAssetAmount();
  error InvalidAmount();
  error AssetLocked();
  error AssetUnlocked();
  error LiquidityRateOverflow();
  error LiquidityIndexOverflow();
  error BorrorRateOverflow();
  error BorrowIndexOverflow();

  function verifyNotZero(address addr) internal pure {
    if (addr == address(0)) {
      revert ZeroAddress();
    }
  }

  function verifyNotZero(bytes32 key) internal pure {
    if (key == bytes32(0)) {
      revert ZeroBytes();
    }
  }

  function verifyNotZero(uint256 num) internal pure {
    if (num == 0) {
      revert ZeroNumber();
    }
  }

  function verifyAreEquals(address ad1, address ad2) internal pure {
    if (ad1 != ad2) {
      revert AddressesNotEquals();
    }
  }

  function verifyAreEquals(uint256 pa1, uint256 pa2) internal pure {
    if (pa1 != pa2) {
      revert NumbersNotEquals();
    }
  }

  function verifyNotExpiredTimestamp(uint256 endTimestamp, uint256 nowTimestamp) internal pure {
    assembly {
      // if (endTimestamp <= nowTimestamp)
      if iszero(gt(endTimestamp, nowTimestamp)) {
        mstore(0x00, 0x26c69d1a) // TimestampExpired() selector
        revert(0x1c, 0x04)
      }
    }
  }

  function verifyExpiredTimestamp(uint256 endTimestamp, uint256 nowTimestamp) internal pure {
    assembly {
      // if (endTimestamp > nowTimestamp)
      if gt(endTimestamp, nowTimestamp) {
        mstore(0x00, 0x2499486c) // TimestampNotExpired() selector
        revert(0x1c, 0x04)
      }
    }
  }
}
