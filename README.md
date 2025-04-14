
# foundry-defi-stablecoin
It is a smart contract project written in [Solidity](https://docs.soliditylang.org/en/latest/) using [Foundry](https://book.getfoundry.sh/).
- It a smart contract I developed leveraging Foundry.
- It is a stablecoin DeFi Protocol similar to DAI.
- My Decentralized Stablecoin has following properties:

  1. Relative Stability: Anchored or Pegged to the US Dollar
    - Chainlink Pricefeed
    - Function to convert ETH & BTC to USD
  2. Stability Mechanism (Minting/Burning): Algorithmicly Decentralized
    - Users may only mint the stablecoin with enough collateral
  3. Collateral: Exogenous (Crypto)
    - wETH
    - wBTC

- Total test coverage is 88% +.



## Getting Started

 - [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git): You'll know you did it right if you can run `git --version` and you see a response like `git version x.x.x`
 - [foundry](https://getfoundry.sh/): You'll know you did it right if you can run `forge --version` and you see a response like `forge 0.2.0 (816e00b 2023-03-16T00:05:26.396218Z)`
 - [make](https://www.gnu.org/software/make/manual/make.html) (optional - either you can install `make` or you can simply substitute the make commands with forge commands by referring to the Makefile after including your .env file): You'll know you did it right if you can run `make --version` and you will see a response like `GNU Make 3.81...`

 
## Installation

- Install foundry-defi-stablecoin
```bash
    git clone https://github.com/yug49/foundry-defi-stablecoin
    cd foundry-defi-stablecoin
```

- Make a .env file
```bash
    touch .env
```

- Open the .env file and fill in the details similar to:
```env
    SEPOLIA_RPC_URL=<YOUR SEPOLIA RPC URL>
    ETHERSCAN_API_KEY=<YOUR ETHERSCAN API KEY>
    SEPOLIA_PRIVATE_KEY=<YOUR PRIVATE KEY>
```
- Remove pre installed cache, unecessary or partially cloned modules modules etc.
```bash
    make clean
    make remove
```

- Install dependencies and libraries.
```bash
    make install
```

- Build Project
```bash
    make build
```



## Deployment

### Deploy On a Local Network (Anvil Testnet)
- To Deploy on a local network first run anvil on your local terminal in current directory by running coommmand: ` make anvil`.
- Now open another terminal and let this one run in the background
- Run the following command:
```bash
make deploy
```

### Deploy on a Sepolia or Any Other Network
- To Deploy on Sepolia, after successfully creating .env file as mentioned above.
- Get youself some Sepolia Eth and LINK tokens and then run command:
```bash
make deploy ARGS="--network sepolia"
```

## Scripts

Instead of scripts, we can directly use the `cast` command to interact with the contract.

For example, on Sepolia:

- Get some WETH

```bash
cast send 0xdd13E55209Fd76AfE204dBda4007C227904f0a81 "deposit()" --value 0.1ether --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
```

- Approve the WETH

```bash
cast send 0xdd13E55209Fd76AfE204dBda4007C227904f0a81 "approve(address,uint256)" <CONTRACT_ADDRESS> 1000000000000000000 --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
```

- Deposit and Mint DSC

```bash
cast send <CONTRACT_ADDRESS> "depositCollateralAndMintDsc(address,uint256,uint256)" 0xdd13E55209Fd76AfE204dBda4007C227904f0a81 100000000000000000 10000000000000000 --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
```


### You can also use Etherscan to interact with the contract:

- Open [sepolia.etherscan.io](https://sepolia.etherscan.io/).
- Search your deployed token contract address.
- Click on Contract tab > Read Contract / Write Contract.
- Connect your web3 wallet.


## Estimate gas
You can estimate how much gas things cost by running:
```bash
make snapshot
```

## Testing

- for local anvil
```bash
    make test
```

## Formatting
- to format all the solidity files:
```bash
    make format
```


## Coverage
- To get test coverage report.
```bash
make test-coverage
```




## 🔗 Links
Loved it? lets connect on:

[![twitter](https://img.shields.io/badge/twitter-1DA1F2?style=for-the-badge&logo=twitter&logoColor=white)](https://x.com/yugAgarwal29)
[![linkedin](https://img.shields.io/badge/linkedin-0A66C2?style=for-the-badge&logo=linkedin&logoColor=white)](https://www.linkedin.com/in/yug-agarwal-8b761b255/)

