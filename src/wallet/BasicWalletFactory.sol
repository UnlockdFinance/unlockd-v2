import {IDelegationWalletRegistry} from '@unlockd-wallet/src/interfaces/IDelegationWalletRegistry.sol';
import {BeaconProxy} from '@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol';
import {IACLManager} from '../interfaces/IACLManager.sol';
import {Errors} from '../libraries/helpers/Errors.sol';
import {BasicWalletVault} from './BasicWalletVault.sol';

contract BasicWalletRegistryFactory {
  address internal immutable _walletVaultBeacon;
  address internal immutable _aclManager;

  /**
   * @dev Modifier that checks if the sender has Protocol ROLE
   */
  modifier onlyProtocol() {
    if (!IACLManager(_aclManager).isProtocol(msg.sender)) {
      revert Errors.ProtocolAccessDenied();
    }
    _;
  }

  /**
   * @dev Modifier that checks if the sender has Emergency ROLE
   */
  modifier onlyEmergency() {
    if (!IACLManager(_aclManager).isEmergencyAdmin(msg.sender)) {
      revert Errors.EmergencyAccessDenied();
    }
    _;
  }

  constructor(address aclManager, address walletVaultBeacon) {
    _walletVaultBeacon = walletVaultBeacon;
    _aclManager = aclManager;
  }

  /**
   * @notice Deploys a new DelegationWallet with the msg.sender as the owner.
   */
  function deploy(address) external returns (address, address, address, address) {
    return deployFor(msg.sender, address(0));
  }

  /**
   * @notice Deploys a new DelegationWallet for a given owner.
   * @param _owner - The owner's address.
   * @param _delegationController - Delegation controller owner
   */
  function deployFor(address _owner, address) public returns (address, address, address, address) {
    address wallletVaultProxy = address(new BeaconProxy(_walletVaultBeacon, new bytes(0)));
    BasicWalletVault(wallletVaultProxy).initialize(_owner);

    // Save wallet
    IDelegationWalletRegistry(registry).setWallet(
      wallletVaultProxy,
      _owner,
      address(0),
      wallletVaultProxy,
      wallletVaultProxy,
      wallletVaultProxy
    );

    emit WalletDeployed(
      wallletVaultProxy,
      _owner,
      wallletVaultProxy,
      wallletVaultProxy,
      wallletVaultProxy,
      msg.sender
    );

    return (wallletVaultProxy, wallletVaultProxy, wallletVaultProxy, wallletVaultProxy);
  }
}
