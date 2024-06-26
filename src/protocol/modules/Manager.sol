// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IManagerModule} from '../../interfaces/modules/IManagerModule.sol';
import {PercentageMath} from '../../libraries/math/PercentageMath.sol';
import {BaseCoreModule} from '../../libraries/base/BaseCoreModule.sol';
import {IACLManager} from '../../interfaces/IACLManager.sol';
import {Errors} from '../../libraries/helpers/Errors.sol';
import {DataTypes, Constants} from '../../types/DataTypes.sol';
import {LoanLogic} from '../../libraries/logic/LoanLogic.sol';

contract Manager is BaseCoreModule, IManagerModule {
  using LoanLogic for DataTypes.Loan;

  constructor(uint256 moduleId_, bytes32 moduleVersion_) BaseCoreModule(moduleId_, moduleVersion_) {
    // NOTHING TO DO
  }

  /**
   * @dev Is a helper where aggregate the function to be standard
   * @param safeERC721 Address of the SafeERC721
   */
  function setSafeERC721(address safeERC721) external onlyAdmin {
    if (safeERC721 == address(0)) revert Errors.ZeroAddress();
    _safeERC721 = safeERC721;
    emit SetSafeERC721(safeERC721);
  }

  /**
   * @dev return the address of this helper
   * @return address return address safeERC721
   */
  function getSafeERC721() external view returns (address) {
    return _safeERC721;
  }

  /**
   * @dev Oracle for the reserve
   * @param oracle Address of the new Reserve Oracle
   */
  function setReserveOracle(address oracle) external onlyAdmin {
    if (oracle == address(0)) revert Errors.ZeroAddress();
    _reserveOracle = oracle;
    emit SetReserveOracle(oracle);
  }

  function getReserveOracle() external view returns (address) {
    return _reserveOracle;
  }

  /**
   *  @dev Set the singer of the messages
   *  @param signer Address of the signer
   */
  function setSigner(address signer) external onlyAdmin {
    if (signer == address(0)) revert Errors.ZeroAddress();
    _signer = signer;
    emit SetSigner(signer);
  }

  /**
   * @dev get address of the signer
   * @return address Address of the signer
   */
  function getSigner() external view returns (address) {
    return _signer;
  }

  /**
   * @dev Set the Wallet registry to check the get the wallets created
   * @param walletRegistry Address of the wallet registry where we can check the addresses
   */
  function setWalletRegistry(address walletRegistry) external onlyAdmin {
    if (walletRegistry == address(0)) revert Errors.ZeroAddress();
    _walletRegistry = walletRegistry;
    emit SetWalletRegistry(walletRegistry);
  }

  /**
   * @dev get wallet registry
   * @return address of the wallet registry
   */
  function getWalletRegistry() external view returns (address) {
    return _walletRegistry;
  }

  /**
   * @dev Set the allowed controller
   * @param allowedControllers Address of the allowed controller
   */
  function setAllowedControllers(address allowedControllers) external onlyAdmin {
    if (allowedControllers == address(0)) revert Errors.ZeroAddress();
    _allowedControllers = allowedControllers;
    emit SetAllowedControllers(allowedControllers);
  }

  /**
   * @dev return allowed controller
   * @return allowedControllers Address of the allowed controller
   */
  function getAllowedController() external view returns (address) {
    return _allowedControllers;
  }

  /**
   * @dev Set the allowed controller
   * @param collection Address of the allowed collection
   * @param reserveType type of the reserve that we allow to borrow.
   */
  function allowCollectionReserveType(
    address collection,
    Constants.ReserveType reserveType
  ) external onlyAdmin {
    if (collection == address(0)) revert Errors.ZeroAddress();
    _allowedCollections[collection] = reserveType;
    emit AllowCollectionReserveType(collection, uint256(reserveType));
  }

  /**
   * @dev Get the collection reserve type
   * @param collection Address of the allowed collection
   * @return reserveType return stuct Constants.ReserveType
   */
  function getCollectionReserveType(
    address collection
  ) external view returns (Constants.ReserveType) {
    return _allowedCollections[collection];
  }

  /**
   * @dev Update the UTokenVault from the protocol
   * @param uTokenVault address of the uTokenVault
   */
  function setUTokenVault(address uTokenVault) external onlyAdmin {
    if (uTokenVault == address(0)) revert Errors.ZeroAddress();
    _uTokenVault = uTokenVault;
    emit SetUTokenVault(uTokenVault);
  }

  /**
   * @dev Get the configured UTokenVault on the protocol
   * @return address return the address of the uTokenVault
   */
  function getUTokenVault() external view returns (address) {
    return _uTokenVault;
  }

  /**
   * @dev Allow Market adapter to interact with the protocol
   * @param adapter Address of the adapter
   * @param active Bolean to allow or disable the UToken on the protocol
   */
  function addMarketAdapters(address adapter, bool active) external onlyGovernance {
    if (adapter == address(0)) revert Errors.ZeroAddress();
    _allowedMarketAdapter[adapter] = active ? 1 : 0;
    if (active) {
      emit ActivateMarketAdapter(adapter);
    } else {
      emit DisableMarketAdapter(adapter);
    }
  }

  /**
   * @dev check is is a avtived Market Adapter
   * @return isActive 1 active 0 disabled
   */
  function isMarketAdapterActive(address adapter) external view returns (uint256) {
    return _allowedMarketAdapter[adapter];
  }

  /**
   * @dev Allow freeze a loan, the current owner can't borrow or add more assets to this loan.
   * @param loanId Loand Id
   */
  function emergencyFreezeLoan(bytes32 loanId) external onlyEmergency {
    if (loanId == bytes32(0)) revert Errors.InvalidLoanId();
    _loans[loanId].freeze();
    emit EmergencyFreezeLoan(loanId);
  }

  /**
   * @dev Allow to activate a loan
   * @param loanId Loand Id
   */
  function emergencyActivateLoan(bytes32 loanId) external onlyEmergency {
    if (loanId == bytes32(0)) revert Errors.InvalidLoanId();
    _loans[loanId].activate();
    emit EmergencyActivateLoan(loanId);
  }

  /**
   * @dev Allow to block a loan
   * @param loanId Loand Id
   */
  function emergencyBlockLoan(bytes32 loanId) external onlyEmergency {
    if (loanId == bytes32(0)) revert Errors.InvalidLoanId();
    _loans[loanId].blocked();
    emit EmergencyBlockLoan(loanId);
  }

  /**
   * @dev Allow to increase the timestamp of a current auction
   * @param orderId order Id
   * @param newEndTime timestamp to finalize the auction
   */
  function emergencyUpdateEndTimeAuction(
    bytes32 orderId,
    uint40 newEndTime
  ) external onlyEmergency {
    if (orderId == bytes32(0)) revert Errors.InvalidOrderId();
    _orders[orderId].timeframe.endTime = newEndTime;
    emit EmergencyUpdateEndTimeAuction(orderId, newEndTime);
  }
}
