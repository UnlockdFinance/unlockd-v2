// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

/**
 * @title IDebtToken
 * @author Unlockd
 * @notice Defines the basic interface for a debt token.
 *
 */
interface IDebtToken {
  /**
   * @dev Emitted when a debt token is initialized
   * @param tokenDecimals the decimals of the debt token
   * @param tokenName the name of the debt token
   * @param tokenSymbol the symbol of the debt token
   *
   */
  event Initialized(uint256 tokenDecimals, string tokenName, string tokenSymbol);

  /**
   * @dev Initializes the debt token.
   * @param aclManager aclManager address
   *
   * @param tokenDecimals The decimals of the debtToken, same as the underlying asset's
   * @param tokenName The name of the token
   * @param tokenSymbol The symbol of the token
   */
  function initialize(
    address aclManager,
    uint8 tokenDecimals,
    string calldata tokenName,
    string calldata tokenSymbol
  ) external;

  /**
   * @dev Emitted after the mint action
   * @param from The address performing the mint
   * @param value The amount to be minted
   * @param index The last index of the reserve
   *
   */
  event Mint(bytes32 loanId, address indexed from, uint256 value, uint256 index);

  /**
   * @dev Mints debt token to the `user` address
   * @param onBehalfOf The beneficiary of the mint
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
  ) external returns (bool);

  /**
   * @dev Emitted when variable debt is burnt
   * @param user The user which debt has been burned
   * @param amount The amount of debt being burned
   * @param index The index of the user
   *
   */
  event Burn(bytes32 loanId, address indexed user, uint256 amount, uint256 index);

  /**
   * @dev Burns user variable debt
   * @param user The user which debt is burnt
   * @param amount The amount to be burnt
   * @param index The variable debt index of the reserve
   *
   */
  function burn(bytes32 loanId, address user, uint256 amount, uint256 index) external;

  /**
   * @dev Returns the address of the incentives controller contract
   *
   */

  function balanceOf(bytes32 loanId, address account) external view returns (uint256);

  /**
   * @dev Returns the scaled balance of the user. The scaled balance is the sum of all the
   * updated stored balance divided by the reserve's liquidity index at the moment of the update
   * @param user The user whose balance is calculated
   * @return The scaled balance of the user
   *
   */
  function scaledBalanceOf(bytes32 loanId, address user) external view returns (uint256);

  /**
   * @dev Returns the scaled total supply of the variable debt token. Represents sum(debt/index)
   * @return The scaled total supply
   *
   */
  function scaledTotalSupply() external view returns (uint256);
}
