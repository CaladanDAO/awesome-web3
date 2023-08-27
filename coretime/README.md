
## CoreTime Design

`CoreTime.sol` is a _prototype_ ERC721 NFT Contract called `CoreTime` that powers project indexing using urls that refer to project configurations in this repository.  

* a `mintNFT` function callable by Caladan DAO takes an input N that creates N tokenIds with a price floor.   Each tokenId is defined by a public url that can be controlled by its owner with a SetUrl function, and any tokenId's public url can be read with a GetUrl function.

* users buy the minted NFT with `buyCoreTime(tokenId int, url string, numDays int16)` which sets the token string and an initial expiration timestamp.   It requires as initial payment 50%
more than the amount paid by the previous owner extends the expiration
by another 90 days.  If no previous owner exists the price floor is
required and the expiration is 90 days.

* Any calls to `extendCoreTime(numDays, tokenId)` extend the expiration time by numDays and requires payment

* All payments go into a `treasuryAddress` initialized in the constructor


## Testing 


1. Install Truffle and Ganache (if not already installed):

npm install -g truffle
npm install -g ganache-cli


2. Run the tests using Truffle:

truffle develop

3. Inside the Truffle development console:

compile
test
