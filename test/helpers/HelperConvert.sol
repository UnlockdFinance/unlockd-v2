// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.19;

library HelperConvert {
  // NOT USE IN PROD
  // This function are not the best aproach for transform but we don't care because is only for testing
  function strToUint(string memory _str) public pure returns (uint256 res, bool err) {
    for (uint256 i = 0; i < bytes(_str).length; i++) {
      if ((uint8(bytes(_str)[i]) - 48) < 0 || (uint8(bytes(_str)[i]) - 48) > 9) {
        return (0, false);
      }
      res += (uint8(bytes(_str)[i]) - 48) * 10 ** (bytes(_str).length - i - 1);
    }

    return (res, true);
  }
}
