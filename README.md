# CaladanDAO's awesome-web3: Organizing the Worlds Web3 + Web3.0 Information

CaladanDAO is an open-source effort to unify two major technology developments of the last decade:
* Web3, which aims to use instrument the web with distributed ledger / blockchain using smart contracts, manifested in ABIs 
* Web3.0, which aims to annotate the web with semantically aware metadata using JSON-LD, pioneered by W3C, manifested in schema.org and widely used eg in Google Rich Media

In both developments, metadata types are used to model semantics.  Web3 uses ABIs to model users interactions with smart contracts in calls and logs, decoded and decorated by indexers eg in a block explorer;
Web3.0 uses JSON-LD markup to assist in indexing eg in Google's search engine.

This repo contains working JSON-LD files to describe Web3 projects (at present, EVM-centric) using "Web 3.0" JSON-LD annotations.  This enables us to:
* model specific projects ([Uniswap](/defi/dex/uniswap), [Curve](/defi/dex/curve), [ENS](/naming/ens)) 
* model aggregations across projects ([defi/dex](defi/dex) modeling swaps, [ethereum/rollup](ethereum/rollup) modeling L1+L2 rollups)
* power a large scale index of Web3 activity in Google BigQuery 

The above design is intended to scale to:
 * ANY project in the Ethereum/EVM ecosystem
 * ANY chain
As new chains are indexed and new projects are modeled in this repo with JSON-LD,  hop will see their contributions generate new  _awesome-web3_ datasets for their real-time.

## Details: How It works

In detail, a "awesome-web3" [Google BigQuery Public Dataset](https://cloud.google.com/bigquery/public-data) contains the following datasets:
 * `awesome-web3.caladan_evm` - full tables -- similar to "crypto_ethereum", except a SET of tables, one for each chain, e.g. Base being chain 8453 has `awesome-web3.caladan_evm.{blocks8453, transactions8453, logs8453, ...}`
 * `awesome-web3.caladan_traces` - partitioned { hourly, daily } datasets of call data 
 * `awesome-web3.caladan_logs` - partitioned { hourly, daily } datasets of call data
 * `awesome-web3.{project}` -- _project-specific_ datasets built from the above partitioned tables **based on `config.jsonc` in this repo**
   - `awesome-web3.naming_ens` holds project tables for [ENS](https://ens.domains/) based on [`/naming/ens/config.jsonc`](/naming/ens/config.jsonc)
   - `awesome-web3.ethereum_optimism`  holds tables for [Optimism](https://www.optimism.io/)  based on [`/ethereum/optimism/config.jsonc`](/naming/ens/config.jsonc)
   - `awesome-web3.defi_dex_uniswap_v2`  holds tables for [Uniswap](https://app.uniswap.org/) based on [`/defi/dex/uniswap/swapv2/config.jsonc`](/defi/dex/uniswap/swapv2/config.jsonc)
   - `awesome-web3.defi_dex_curve`  holds tables for [Curve](https://curve.fi/) based on [`/defi/dex/curve/config.jsonc`](/defi/dex/curve/config.jsonc)
   - `awesome-web3.funding_gitcoin_allo`  holds tables for [GitCoin Allo](https://allo.gitcoin.co/) across multiple chains (Ethereum, Public Goods Network) based on [`/funding/gitcoin/allo/config.jsonc`](/funding/gitcoin/allo/config.jsonc)
 * `awesome-web3.{recipe}` contains aggregations across multiple projects ***based on `Recipe` JSON-LD objects seen across projects in this repo.***  Examples:
   - `awesome-web3.dex_trades` holds aggregatation across uniswap + curve.

JSON-LD files are organized in hierarchical folders (e.g `defi/dex/uniswap/swapv2`) with a file naming convention of:
* Conceptual Schemas (Smart Contract ABIs in JSON-LD form) are kept in `index.jsonld` at the root of a folder
* Project Configurations are kept in `config.jsonc` at the root of a folder
* Sample Instances are kept in a `samples` subdirectory with a `{callName}Call.jsonld` * `samples/{XYZ}Event.jsonld`, which aid in modeling
* Data summaries of recent calls + logs are kept in a `data` subdirectory, which also aid in prioritizing  ABI modeling 


The interconnectedness of contracts can be seen in the following widely used systems:

* ERC20: [Transfer(address,address,amount)](/ethereum/token/erc20) illustrates how the amount references 
* DEX: [Curve TokenExchange](/defi/dex/curve) and [Uniswap Swapv2](/defi/dex/uniswap/swapv2) events illustrate how multiple ERC20s are referenced in Pairs and Registries 
* DEX Trades: In the above JSON-LD there is are `Recipe` features and labels, which support a "Trades" recipe
* Optimism Superchain: [ERC20DepositInitiated](/ethereum/optimism) events illustrate a 

It is expected that covering a larger array of projects and recipes will necessarily motivate proper JSON-LD treatment of:
* `bytes`
* internal types/interfaces
* [UDFs](https://cloud.google.com/bigquery/docs/user-defined-functions)

#### Indexing: How It Works

A multichain evm-etl indexing process is driven by the JSON-LD repos in this repo

A regular reindexing process is conducted:
* over the recent day every hour
* over the recent month every day
* over the recent quarter every week
* over the recent year every 4-6 weeks
* over the recent 3 years every 10-12 weeks

This enables project modelers to get rapid feedback for their project configuration during development, while getting predictable "crawler" 

## Goals

### Goal 1: Model Web3 Semantics with Web3.0 JSON-LD schemas

We build upon the following pioneering efforts to model Web3 semantics and develop large-scale indexes of Web3:

* [EthOn](https://ethon.consensys.net/), who developed a JSON-LD schema for top level Ethereum types following [Schema.org](https://schema.org) 
* [L2 Beat's config/discovery system](https://l2beat.com) which showed how complex Ethereum L1+L2 patterns can be modeled with JSON
* [Nansen](https://www.nansen.ai/) + [blockchain-etl](https://github.com/blockchain-etl) who demonstrated large scale decoding of raw data within Google BigQuery
* [Dune Spellbook](https://dune.com/docs/data-tables/spellbook/) developed high-performance staged dataflows with similarly detailed project models, working in conjunction with a "wizard" community 

### Goal 2: Community Supported Web3/3.0 Indexing with a Web3 Quadratic Funding Model

We are designing (with the help of the Gitcoin team, led by Meg
Lister) a suitable [Gitcoin Grants Program](https://caladandao.org)
for the CaladanDAO, see
[here](https://docs.google.com/document/d/1dp_nWozPtII04horcb186gUUTTVhPad0sKjNcjgfGHI/edit#heading=h.ner56sbza2ns).
We envision project owners requesting that their project be modeled or
aggregated, and data analysts and engineers receiving Quadratic
Funding for their work, directly from contributors or those who stand
to gain the most from the work.  

It is widely recognized that the most widely used open source systems
(eg Wikipedia, Linux) undercompensate their contributors and value is
captured by others (eg Cloud providers, Search/LLM Engines).  It is
also widely recognized that Web3 DAOs are quite slow and ineffective
at compensating contributors, especially new and unproven ones.  It is hoped that Gitcoin Allo Quadratic Funding model,
made newly practical within the Public Goods Network L2, enables decentralized data engineering.

 
Using Web3 technologies of [Gitcoin Allo](https://allo.gitcoin.co/),
we aim for a suitable licensing + attribution model wherein:

* project modelers and recipe builders are incentivized to model specific projects and project aggregations
* project developers and the general community can support the above efforts reliably

In contrast, an outcome where Web3/3.0 metadata is exploited by a
select few companies (eg Google, etherscan, OpenAI, etc) should be
actively avoided.  A balance must be struck where the effort has high
impact (e.g. Wikipedia) while valuing the contributors who made it
possible.

No one team or company can attempt to model the entirety of all
project's Web3 semantics at the tip of innovation: the relevant
knowledge requires not just an ABI but detailed knowledge of how a set
of contracts actually work, and such knowledge is likely to come from
set of decentralized data engineers.  It is of course possible, and
maybe inevitable, that a future version of a LLM like ChatGPT, given
sufficient JSON-LD metadata from repos such as this, could in the near
future automatically decompile on chain byte code and reliably
generate near perfect JSON-LD with little to no human intervention.
In the meantime, engineering Web3/3.0 models for indexing will be a
human-machine collective collaboration.

## Chain Support

Multiple EVM chains in the "awesome-web3" project

* Ethereum (1) - in progress as of August 2023
* Public Goods (424) - in progress
* Base (8453) - in progress as of August 2023
* Optimism (10) - planned September 2023
* Arbitrum - planned September 2023
* Moonbeam (1284) - planned September 2023
* Astar (1285) - planned Q4 2023
* Moonriver (1285) - planned Q4 2023
* Solana - planned Q4 2023
* Polygon - planned Q4 2023


## Support / Acknowledgements

* The "awesome-web3" project dataset is generously supported by the [Google
Cloud Web3](https://cloud.google.com/web3), most notably [Allen
Day](https://allen.day) and the extended Web3 team.
* Colorful Notion is supported in part by Polkadot Treasury for its [substrate-etl](https://github.com/colorfulnotion/substrate-etl), a sister of the evm-etl indexer used in this project
* Raw Signatures database is from the amazingly useful openchain.xyz





