# Unlockd NFT Custody

**Note:** For extended documentation, please refer to [/docs](/docs)

## Architecture

![nft-custody-architecture](/docs/images/architecture.jpg)

## Definitions

**Delegation Wallet:** a set of 3 smart contracts (A Safe smart contract wallet, a DelegationOwner and a DelegationGuard) working together to provide delegation and lock functionalities

**DelegationOwner:** a smart contract that is set as one of the owners of the Safe wallet, it contains the logic related to delegations, locks and using delegated NFTs.

**DelegationGuard:** a smart contract that is set as the guard of the Safe, it contains the logic that freezes the NFT and some Safe configuration

**To freeze a NFT:** to not allow it to be transferred out of the wallet.

**To Delegate a NFT**, is to give permission to a given account to execute some functions or sign off-chain messages like if it were the owner of the NFT until an end date. It freezes the NFT until the pre-established delegation end date, after that date is automatically un-freezed. This is used for use cases like rentals, where we give temporary usage of the asset to an address.

- An NFT can only be delegated by the delegation controller.
- An NFT can only be delegated to 1 address at a time.

**Locking a NFT** freezes the asset until it is unlocked, at any moment, there is no pre-established end date (e.g. the borrower pays back the loan) or claimed after a specified claim date (e.g. the lender claims the collateral asset of a defaulted loan). The Lock only ensures the asset will remain in the wallet/escrow for a time, there’s no delegation.

- The asset is unfrozen ONLY when it is UNLOCKED.
- An NFT can only be locked by the lock controller.
- An NFT can only be claimed by the lock controller if it is locked and it is not delegated or the claimDate is passed.

**To Claim a NFT** is to transfer it out of the safe to a given receiver, it is allowed if the asset is locked and the claim date is passed.

Claim date = loan expiry

## Lock and Delegation Rules

**R#1 -** When delegating a locked NFT, the delegation end date should be LTE the lock claim date.

**R#2 -** When locking a delegated NFT, the lock claim date should be GTE delegation endDate

**R#1 and R#2** ensure that a delegation will always end before or at the lock claim date.

## Audit Reports

### Halborn

- [6 March 2023](/docs/audits/NFTfi_Delegation_Wallet_Smart_Contract_Security_Audit_Report_Halborn_Final.pdf)

## Installation

_Having issues? See the [troubleshooting section](https://github.com/foundry-rs/foundry/blob/master/README.md#troubleshooting-installation)_.

First run the command below to get `foundryup`, the Foundry toolchain installer:

```sh
curl -L https://foundry.paradigm.xyz | bash
```

If you do not want to use the redirect, feel free to manually download the
foundryup installation script from
[here](https://raw.githubusercontent.com/foundry-rs/foundry/master/foundryup/foundryup).

Then, run `foundryup` in a new terminal session or after reloading your `PATH`.

Other ways to use `foundryup`, and other documentation, can be found [here](https://github.com/foundry-rs/foundry/tree/master/foundryup). Happy forging!

## Install dependencies

### Yarn

```
yarn install
```

### Forge

```
forge install
```

## Run tests

Create an `.env` file using `.env.example` as template, then run

```
yarn test:all
```
