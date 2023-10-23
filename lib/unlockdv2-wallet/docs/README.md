# Unlockd NFT Custody documentation

## Index

- [Smart Contracts Overview](#smart-contracts-overview)
  - [Architecture Diagram](#architecture-diagram)
  - [Components](#components)
- [Workflows](#workflows)
  - [Off-chain log-in](#off-chain-log-in)
  - [Execute transaction](#execute-transaction)

## Smart Contracts Overview

### Architecture Diagram

![architecture-diagram](/docs/images/architecture-extended.png)

### Components

#### DelegationWalletFactory

- Deploys a new Safe, DelegationOwner (beacon proxy) and DelegationGuard (beacon proxy)
- Configures the new Safe with the user and delegationOwner as the owners, threshold 1 and sets delegationGuard as the Safe's guard
- Registers the new contracts in DelegationWalletRegistry

#### DelegationWalletRegistry

- Registry contract that stores information related to the Delegation Wallets deployed by the DelegationWalletFactory contract. This contract can be used as a reliable source to validate that a given address is a valid Delegation Wallet.

#### DelegationController NOT INCLUDED

- External contract with delegationController role in DelegationOwner
- Can delegate an NFT or delegate Safe signature, freezing the NFT (or multiple if delegating signature) on the Safe

#### LockController (e.g. NFTfi) NOT INCLUDED

- External contract with loanController role
- Can lock, unlock and claim NFTs.
- e.g. NFTfi new loan contract locks the NFT used as collateral (in the borrower DW) when the loan is created, then it unlocks the NFT if the loan is paid back or claims it when the loan is liquidated. The borrower can continue using the NFT (e.g. claim an Airdrop) during the loan period.

#### DelegationRecipes

- A registry for allowed functions by collection.
- Functions are grouped by target contract and asset collection.

#### AllowedControllers

- Registry for allowed addresses to be used as lock or delegation controllers in a DelegationWallet.

#### DeleagtionOwnerBeacon

- UpgradableBeacon
- Only owner can upgrade implementation

#### DelegationOwnerProxy

- Beacon Proxy instance
- Takes implementation from DelegationOwnerBeacon

#### DelegationOwnerImpl

- Contract implementing the logic executed by the DelegationOwnerProxy
- Initializabe to be used as proxy implementation
- Used by delegate to execute transactions though the Safe which holds a delegated NFT
- Uses DelegationRecipes to validate if a given function is allowed
- Validates user signature if the Owner is delegating a the Safe signature
- Is used by delegationController role for delegating NFTs and Safe signature
- Is used by NFTfi (loanController role) for locking, unlocking and claiming NFTs used as loan collateral

#### DelegationGuardBeacon

- Is UpgradableBeacon
- Only owner can upgrade implementation

#### DelegationGuardProxy

- Beacon Proxy instance
- Takes implementation from DelegationGuardBeacon

#### DelegationGuardImpl

- Contract implementing the logic executed by the DelegationGuardProxy
- Initializabe to be used as proxy implementation
- Prevents frozen NFTs from being transferred
- Prevents the approval of frozen NFTs
- Prevents all approveForAll
- Prevents change in the configuration of the DelegationWallet

#### Gnosis Safe

- A GnosisSafe multisig wallet configured with at least 2 owners, a threshold of 1 and a SafeGuard contract set as the Safe’s guard.
- The first owner is the owner of the NFTs, the second one is the DelegationOwner contract.
- Allows the NFT owner to use its NFT while it is deposited in the Safe, since it is also a Safe owner
- Provides GS contract type signature

#### SomeContract

- An external smart contract that requires owning some NFT to execute its functions

## Workflows

### Off-chain log-in

![off-chain-log-in-flow](/docs/images/workflow-off-chain-login.png)

### Execute transaction

![execute-transaction-flow](/docs/images/workflow-execute-transaction.png)
