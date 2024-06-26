<!-- prettier-ignore-start -->
```        
██╗   ██╗███╗   ██╗██╗      ██████╗  ██████╗██╗  ██╗██████╗     ██╗   ██╗██████╗ 
██║   ██║████╗  ██║██║     ██╔═══██╗██╔════╝██║ ██╔╝██╔══██╗    ██║   ██║╚════██╗
██║   ██║██╔██╗ ██║██║     ██║   ██║██║     █████╔╝ ██║  ██║    ██║   ██║ █████╔╝
██║   ██║██║╚██╗██║██║     ██║   ██║██║     ██╔═██╗ ██║  ██║    ╚██╗ ██╔╝██╔═══╝ 
╚██████╔╝██║ ╚████║███████╗╚██████╔╝╚██████╗██║  ██╗██████╔╝     ╚████╔╝ ███████╗
 ╚═════╝ ╚═╝  ╚═══╝╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝╚═════╝       ╚═══╝  ╚══════╝
```                                                                                         
<!-- prettier-ignore-end -->

## Oficial link

https://unlockd.finance/

DOCS: https://docs.unlockd.finance/

# Run this repo

## This project uses Foundry

https://book.getfoundry.sh/

## Installation

Install the latest release by using foundryup

This is the easiest option for Linux and macOS users.

Open your terminal and type in the following command:

```
curl -L https://foundry.paradigm.xyz | bash
```

This will download foundryup. Then install Foundry by running:

```
foundryup
```

## Build

```
forge build
```

## Run tests

```
forge test
```

Useful commands:

#### Show logs on tests

```
forge test -vv
```

#### Show logs for all the interactions

```
forge test -vvvv
```

#### Run test single file

```
forge test --match-path test/RepayTest.t.sol
```

#### Run coverage

```
forge coverage --ir-minimum --report lcov
```

# deploy

To verify add ' --verify --etherscan-api-key ${ETHERSCAN_API_KEY_SEPOLIA}' on the make script

1 - make deploy-sep-aclmanager

2 - make deploy-sep-wallet

3 - make deploy-sep-periphery

4 - make deploy-sep-protocol

5 - make deploy-sep-allow
