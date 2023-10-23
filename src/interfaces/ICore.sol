// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

interface ICore {
  event Genesis();

  event ProxyCreated(address indexed proxy, uint256 moduleId);

  event InstallerInstallModule(
    uint256 indexed moduleId,
    address indexed moduleImpl,
    bytes32 moduleVersion
  );
}
