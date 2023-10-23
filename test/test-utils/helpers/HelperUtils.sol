// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.19;

import {IDebtToken} from '../../../src/interfaces/tokens/IDebtToken.sol';
import {IUToken} from '../../../src/interfaces/tokens/IUToken.sol';
import {WadRayMath} from '../../../src/libraries/math/WadRayMath.sol';

library HelperUtils {
  using WadRayMath for uint256;

  function toBytes(uint256 x) internal pure returns (bytes memory b) {
    b = new bytes(32);
    assembly {
      mstore(add(b, 32), x)
    }
  }

  function getUserDebtInBaseCurrency(
    bytes32 loanId,
    address user,
    address uToken
  ) internal view returns (uint256) {
    if (loanId == 0) return 0;
    uint256 userTotalDebt = IDebtToken(IUToken(uToken).getDebtToken()).scaledBalanceOf(
      loanId,
      user
    );
    userTotalDebt = userTotalDebt.rayMul(IUToken(uToken).getReserveNormalizedVariableDebt());
    return userTotalDebt;
  }

  function toHex16(bytes16 data) internal pure returns (bytes32 result) {
    result =
      (bytes32(data) & 0xFFFFFFFFFFFFFFFF000000000000000000000000000000000000000000000000) |
      ((bytes32(data) & 0x0000000000000000FFFFFFFFFFFFFFFF00000000000000000000000000000000) >> 64);
    result =
      (result & 0xFFFFFFFF000000000000000000000000FFFFFFFF000000000000000000000000) |
      ((result & 0x00000000FFFFFFFF000000000000000000000000FFFFFFFF0000000000000000) >> 32);
    result =
      (result & 0xFFFF000000000000FFFF000000000000FFFF000000000000FFFF000000000000) |
      ((result & 0x0000FFFF000000000000FFFF000000000000FFFF000000000000FFFF00000000) >> 16);
    result =
      (result & 0xFF000000FF000000FF000000FF000000FF000000FF000000FF000000FF000000) |
      ((result & 0x00FF000000FF000000FF000000FF000000FF000000FF000000FF000000FF0000) >> 8);
    result =
      ((result & 0xF000F000F000F000F000F000F000F000F000F000F000F000F000F000F000F000) >> 4) |
      ((result & 0x0F000F000F000F000F000F000F000F000F000F000F000F000F000F000F000F00) >> 8);
    result = bytes32(
      0x3030303030303030303030303030303030303030303030303030303030303030 +
        uint256(result) +
        (((uint256(result) + 0x0606060606060606060606060606060606060606060606060606060606060606) >>
          4) & 0x0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F) *
        7
    );
  }

  function toHex(bytes32 data) public pure returns (string memory) {
    return string(abi.encodePacked('0x', toHex16(bytes16(data)), toHex16(bytes16(data << 128))));
  }
}
