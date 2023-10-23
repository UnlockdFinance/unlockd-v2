// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {UUPSUpgradeable} from '@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol';

import {IUToken} from '../interfaces/tokens/IUToken.sol';
import {IDebtToken} from '../interfaces/tokens/IDebtToken.sol';
import {BaseERC20, Errors, DataTypes} from '../libraries/base/BaseERC20.sol';

import {WadRayMath} from '../libraries/math/WadRayMath.sol';

/**
 * @title DebtToken
 * @notice Implements a debt token to track the borrowing positions of users
 * @author Unlockd
 *
 */
contract DebtToken is IDebtToken, BaseERC20, UUPSUpgradeable {
  using WadRayMath for uint256;

  uint256 internal _totalSupply;
  mapping(address => uint256) internal _balances;
  mapping(bytes32 => mapping(address => uint256)) internal _balances_by_id;

  address internal _uToken;
  address internal _incentivesController;
  uint8 internal _decimals;

  modifier onlyUToken() {
    if (msg.sender != _uToken) revert Errors.UTokenAccessDenied();
    _;
  }

  /**
   * @dev Initializes the debt token.
   * @param aclManager ACLManager aclManager
   * @param tokenDecimals The decimals of the debtToken, same as the underlying asset's
   * @param tokenName The name of the token
   * @param tokenSymbol The symbol of the token
   */
  function initialize(
    address aclManager,
    uint8 tokenDecimals,
    string calldata tokenName,
    string calldata tokenSymbol
  ) public initializer {
    __BaseERC20_init(aclManager, tokenName, tokenSymbol);
    _decimals = tokenDecimals;
    emit Initialized(tokenDecimals, tokenName, tokenSymbol);
  }

  function setUToken(address uToken) public onlyAdmin {
    _uToken = uToken;
  }

  /**
   * @dev Mints debt token to the `user` address
   * -  Only callable by the UToken
   * @param amount The amount of debt being minted
   * @param index The variable debt index of the reserve
   * @return `true` if the the previous balance of the user is 0
   *
   */
  function mint(
    bytes32 loanId,
    address onBehalfOf,
    uint256 amount,
    uint256 index
  ) external override onlyUToken returns (bool) {
    // index is expressed in Ray, so:
    uint256 amountScaled = amount.rayDiv(index);
    if (amountScaled == 0) {
      revert Errors.InvalidAmount();
    }

    uint256 previousBalance = _mint(loanId, onBehalfOf, amountScaled);

    emit Mint(loanId, onBehalfOf, amount, index);

    return previousBalance == 0;
  }

  /**
   * @dev Burns user variable debt
   * - Only callable by the LendPool
   * @param user The user whose debt is getting burned
   * @param amount The amount getting burned
   * @param index The variable debt index of the reserve
   *
   */
  function burn(bytes32 loanId, address user, uint256 amount, uint256 index) external onlyUToken {
    uint256 amountScaled = amount.rayDiv(index);
    if (amountScaled == 0) {
      revert Errors.InvalidAmount();
    }

    _burn(loanId, user, amountScaled);

    emit Burn(loanId, user, amount, index);
  }

  /**
   * @notice Checks authorization for UUPS upgrades
   * @dev Only ACL manager is allowed to upgrade
   */
  function _authorizeUpgrade(address) internal override onlyAdmin {}

  /**
   * @dev Calculates the accumulated debt balance of the user
   * @return The debt balance of the user
   *
   */
  function balanceOf(bytes32 loanId, address user) public view virtual returns (uint256) {
    return
      _balances_by_id[loanId][user].rayMul(IUToken(_uToken).getReserveNormalizedVariableDebt());
  }

  /**
   *  @dev Total amount of debt for a especific address
   * @param account address of the account to check
   *
   */
  function balanceOf(address account) public view virtual override returns (uint256) {
    return _balances[account].rayMul(IUToken(_uToken).getReserveNormalizedVariableDebt());
  }

  /**
   * @dev Returns the principal debt balance of the user from segmented by LoanId
   * @return The debt balance of the user since the last burn/mint action
   *
   */
  function scaledBalanceOf(bytes32 loanId, address user) public view virtual returns (uint256) {
    return _balances_by_id[loanId][user];
  }

  /**
   * @dev Returns the total supply of the variable debt token. Represents the total debt accrued by the users
   * @return The total supply
   *
   */
  function totalSupply() public view virtual override returns (uint256) {
    return _totalSupply.rayMul(IUToken(_uToken).getReserveNormalizedVariableDebt());
  }

  /**
   * @dev Returns the scaled total supply of the variable debt token. Represents sum(debt/index)
   * @return the scaled total supply
   *
   */
  function scaledTotalSupply() public view virtual override returns (uint256) {
    return _totalSupply;
  }

  /**
   * @dev Decimals of the token
   * */
  function decimals() public view virtual override returns (uint8) {
    return _decimals;
  }

  /////////////////////// DISABLED FUNCTIONS ///////////////////////

  /**
   * @dev Being non transferrable, the debt token does not implement any of the
   * standard ERC20 functions for transfer and allowance.
   **/
  function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
    recipient;
    amount;
    revert Errors.NotImplemented();
  }

  function allowance(
    address owner,
    address spender
  ) public view virtual override returns (uint256) {
    owner;
    spender;
    revert Errors.NotImplemented();
  }

  function approve(address spender, uint256 amount) public virtual override returns (bool) {
    spender;
    amount;
    revert Errors.NotImplemented();
  }

  function transferFrom(
    address sender,
    address recipient,
    uint256 amount
  ) public virtual override returns (bool) {
    sender;
    recipient;
    amount;
    revert Errors.NotImplemented();
  }

  function increaseAllowance(
    address spender,
    uint256 addedValue
  ) public virtual override returns (bool) {
    spender;
    addedValue;
    revert Errors.NotImplemented();
  }

  function decreaseAllowance(
    address spender,
    uint256 subtractedValue
  ) public virtual override returns (bool) {
    spender;
    subtractedValue;
    revert Errors.NotImplemented();
  }

  ///////////////////////////////////////////////////////
  /////////////////////// PRIVATE ///////////////////////
  ///////////////////////////////////////////////////////

  function _burn(bytes32 loanId, address account, uint256 amount) internal virtual {
    if (account == address(0)) revert Errors.ZeroAddress();

    uint256 accountBalance = _balances[account];
    uint256 loanBalance = _balances_by_id[loanId][account];

    assembly ('memory-safe') {
      // if (accountBalance < amount || loanBalance < amount) revert Errors.AmountExceedsBalance();
      if or(lt(accountBalance, amount), lt(loanBalance, amount)) {
        mstore(0x00, 0x96ab19c8) // AmountExceedsBalance() selector
        revert(0x1c, 0x04)
      }
    }

    unchecked {
      _balances[account] = accountBalance - amount;
      _balances_by_id[loanId][account] = loanBalance - amount;
      // Overflow not possible: amount <= accountBalance <= totalSupply.
      _totalSupply -= amount;
    }

    emit Transfer(account, address(0), amount);
  }

  function _mint(
    bytes32 loanId,
    address account,
    uint256 amount
  ) internal virtual returns (uint256 previousBalance) {
    if (account == address(0)) revert Errors.ZeroAddress();

    previousBalance = _balances_by_id[loanId][account];

    _totalSupply += amount;

    unchecked {
      // Overflow not possible: balance + amount is at most totalSupply + amount, which is checked above.
      _balances[account] += amount;
      _balances_by_id[loanId][account] = previousBalance + amount;
    }
    emit Transfer(address(0), account, amount);
  }
}
