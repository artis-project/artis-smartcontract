# artis-smartcontract
This repository contains the solidity code which defines the smartcontract for all the artwork NFTs. 

## External services setup

### Ethereum managed fullnode

[alchemy](https://www.alchemy.com/) is a web3 development platform that offers managed services such as an ethereum fullnode. For this project we are using this service and have followed the following steps:

- Sign up and create a new app
- copy the provider-url for later (https://eth-sepolia.g.alchemy.com/v2/<api-key>)

### Metamask accounts & wallets

[metamask](https://metamask.io/) is a web3 wallet provider that simplifies blockchain wallet and account creation. For this project we need multiple accounts that are easily created with metamask.

- Sign up for metamask
- create accounts for
    - the smartcontract admin
    - the logger
- note the private key for later

### Etherscan

[etherscan](https://etherscan.io/apis) is an ethereum block explorer that provides an api that this project is using to dynamically access the abi of the deployed artis-smartcontract.

- create an etherscan account
- note the api-key for later

### Github Variables

Because the services in this project are intertwined we use github variables at an organization level to share two pieces of information. Firstly the address of the deployed smartcontract that is consumed by the *artis-server* to interact with the newest deployed contract and secondly the API url of the deployed *artis-server* instance that is consumed by the *artis-rockpi-logger* in order to query the newest version of the deployed REST API.

To create or update these variables manually:

```bash
gh variable set ARTIS_API_URL --org artis-project
gh variable set ARTIS_SC_ADDRESS --org artis-project
```

In our CI/CD setup these variables are updated (automatically) and queried by each service independently. In order to authenticate we are using personal access tokens:

- create a fine-grained personal access token to allow reading and writing to variables (if you want you can seperate read and write into two tokens)
    - to allow personal access tokens: artis-project > settings > Third-party Access > Personal access tokens > Allow access via fine-grained access tokens > do not require administrator approval > Allow access via personal access tokens (classic) > enroll
        - or ask an administrator to do this for you
    - to create: <your github account> > settings > Developer settings > Personal access tokens > Fine-grained tokens > generate new token
        - name: ACCESS_ARTIS_ORG_VARIABLES
        - Resource owner: artis-project
        - Permissions > Organizations permissions > Variables > Read and write
        - generate token and note for later

## Deployment
It uses github actions to autmatically deploy the smartcontract to the ethereum testnet on merge to the dev branch. The contract can also be deployed manually:

```bash
npm install
npx hardhat run scripts/deploy.ts --network sepolia
npx hardhat verify <sc-address> --network sepolia
```

The deployment script is also in need of some variables which can be configured in a .env file for manual deployment or as repository secrets for the github actions deployment.

`.env`
---
SMARTCONTRACT_ADMIN_PRIVATE_KEY = \<smartcontract-admin-private-key\> *(0x prefix!)*

ARTIS_SC_VARIABLE_NAME = "ARTIS_SC_ADDRESS"

ARTIS_ORG_NAME = "artis-project"

UPDATE_ORG_VARIABLES_TOKEN = \<personal access token to update org variables\>

ALCHEMY_PROVIDER_URL = \<fullnode-rpc-endpoint\>

ETHERSCAN_API_KEY = \<etherscan-api-key\>

---

## Learn More
If you want to know more about the project check out the full project report in the [artis-thesis](https://github.com/artis-project/artis-thesis) repository
