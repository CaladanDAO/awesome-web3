# awesome-web3: CaladanDAO - Web3.1 Projects

This repo contains human-curated project definitions for "Web3" projects (from Ethereum L1+L2 chains) using "Web 3.0" JSON-LD annotations, and is used to power a Google BigQuery Public Dataset of "awesome-web3"
containing:
 * `awesome-web3.caladan_evm` - full tables -- similar to "crypto_ethereum", except a SET of tables, one for each chain
 * `awesome-web3.caladan_traces` - partitioned { hourly, daily } datasets of call data 
 * `awesome-web3.caladan_logs` - partitioned { hourly, daily } datasets of call data
 * `awesome-web3.{project}` -- project-specific datasets built from the above partitioned tables

Goal: anyone who contributes a project definition to this repo will automatically see their project model result in _project-specific_ datasets that can result in _awesome_ "Web3" datasets.


The project definitions involve:
* specifying the semantics of ABI signatures in JSON-LD form, using "@type" and "@context" to reference event schema -- this affects the decoration process as well as project generation
* specifying which ABI signatures should result in tables and roll up into aggregated "spells" tables

Background:
* Ethereum Projects are now defined by a set of interconnected Smart Contracts with elaborate ABIs.  The world is undergoing an [L2 Big Bang](https://l2beat.com), with Optimism and Arbitrum being followed by Base and scaling through EIP4844 and a large number of promising ZK L2s.  Most projects now systematically deploy on multiple chains, for maximal impact.
* [L2 Beat discovery system](https://l2beat.com) has a "discovery" system, but is missing JSON-LD semantics

## Repo Organization

* [projects](/projects) holds project configurations.  Anyone can contribute a new project definition.
* [libraries](/libraries) hold libraries common to many different projects

## How It Works

Multiple EVM chains in the "awesome-web3" project with the "evm-etl" (not released yet), using the latest available ABIs + project definitions in this repo.

* Ethereum (1) - in progress
* Base (8453) - in progress
* Public Goods (424) - in progress
* Optimism (10) - planned Q3
* Arbitrum - planned Q3
* Moonbeam (1284) - planned Q3
* Moonriver (1285) - planned Q3
* Astar (592) - planned Q3
* Shiden - planned Q3
* Solana - planned Q4
* Polygon - planned Q4

The recent past is regularly reindexed more than the distant past, and projects datasets are rebuilt hourly/daily.








