// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.19;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {IProtocolOwner} from '@unlockd-wallet/src/interfaces/IProtocolOwner.sol';
import {IDelegationWalletRegistry} from '@unlockd-wallet/src/interfaces/IDelegationWalletRegistry.sol';

import {IMarketAdapter} from '../../../src/interfaces/adapter/IMarketAdapter.sol';
import {BaseCoreModule, IACLManager} from '../../../src/libraries/base/BaseCoreModule.sol';

import {GenericLogic} from '../../../src/libraries/logic/GenericLogic.sol';
import {LoanLogic} from '../../../src/libraries/logic/LoanLogic.sol';
import {SellNowLogic} from '../../../src/libraries/logic/SellNowLogic.sol';
import {ValidationLogic} from '../../../src/libraries/logic/ValidationLogic.sol';
import {OrderLogic} from '../../../src/libraries/logic/OrderLogic.sol';

import {MathUtils} from '../../../src/libraries/math/MathUtils.sol';

import {TestSign} from './TestSign.sol';

import {Errors} from '../../../src/libraries/helpers/Errors.sol';
import {DataTypes} from '../../../src/types/DataTypes.sol';

contract Test is BaseCoreModule, TestSign {
  event EverythingItsOk();
  uint256 internal _lastRandom;

  constructor(uint256 moduleId, bytes32 moduleVersion) BaseCoreModule(moduleId, moduleVersion) {
    // NOTHING TO DO
  }

  function executeTest(
    uint256 random,
    SignTest calldata signTest,
    DataTypes.EIP712Signature calldata sig
  ) external {
    address msgSender = unpackTrailingParamMsgSender();
    _validateSignature(msgSender, signTest, sig);

    emit EverythingItsOk();
  }
}
