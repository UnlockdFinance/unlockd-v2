// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from 'forge-std/console.sol';

contract GasHelpers {
  string private checkpointLabel;
  uint256 private checkpointGasLeft = 1; // Start the slot warm.

  function startGas(string memory label) internal virtual {
    checkpointLabel = label;
    checkpointGasLeft = gasleft();
  }

  function stopGas() internal virtual {
    uint256 checkpointGasLeft2 = gasleft();

    // Subtract 100 to account for the warm SLOAD in startMeasuringGas.
    uint256 gasDelta = checkpointGasLeft - checkpointGasLeft2 - 100;

    console.log(string(abi.encodePacked(checkpointLabel, ' Gas')), gasDelta);
  }
}
