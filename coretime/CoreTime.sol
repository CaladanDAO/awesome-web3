// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract CoreTime is ERC721Enumerable, Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    address public treasuryAddress;
    uint256 public priceFloorEth;
    uint16 public constant EXPIRATION_INCREMENT = 90;
    uint8 public constant REFUND_PERCENTAGE = 20; // 80% refund to the owner

    uint256 public ethToTokenRate; // Rate of tokens per ETH
    address public governanceTokenAddress;

    struct TokenInfo {
        string url;
        uint256 expirationTimestamp;
        address owner;
        address creatorAddress;
    }

    mapping(uint256 => TokenInfo) private tokenInfo;

    constructor(
        address _treasuryAddress,
        uint256 _priceFloorEth,
        uint256 _ethToTokenRate,
        address _governanceTokenAddress
    ) ERC721("CoreTime", "CT") {
        treasuryAddress = _treasuryAddress;
        priceFloorEth = _priceFloorEth;
        ethToTokenRate = _ethToTokenRate;
        governanceTokenAddress = _governanceTokenAddress;
    }

    function setEthToTokenRate(uint256 _rate) external onlyOwner {
        ethToTokenRate = _rate;
    }

    function mintNFT(uint256 _numTokens, address _creatorAddress) external onlyOwner {
        for (uint256 i = 0; i < _numTokens; i++) {
            uint256 tokenId = totalSupply() + 1;
            _mint(owner(), tokenId);
            tokenInfo[tokenId] = TokenInfo("", 0, owner(), _creatorAddress);
        }
    }

    function setUrl(uint256 _tokenId, string memory _url) external {
        require(_exists(_tokenId), "Token does not exist");
        require(msg.sender == tokenInfo[_tokenId].owner, "Only token owner can set URL");
        tokenInfo[_tokenId].url = _url;
    }

    function getUrl(uint256 _tokenId) external view returns (string memory) {
        return tokenInfo[_tokenId].url;
    }

    function buyCoreTime(uint256 _tokenId, string memory _url) external payable nonReentrant {
        require(_exists(_tokenId), "Token does not exist");
        require(msg.sender != address(0), "Invalid sender");
        TokenInfo storage token = tokenInfo[_tokenId];
        uint256 currentPriceEth = getCurrentPriceETH(_tokenId);

        require(msg.value >= currentPriceEth, "Insufficient ETH payment");
        uint256 requiredPayment = msg.value;

        uint256 newExpiration = block.timestamp + EXPIRATION_INCREMENT;

        // If this is the first purchase, use the price floor
        if (currentPriceEth == 0) {
            require(requiredPayment >= priceFloorEth, "Price must be at least the floor price");
            newExpiration = block.timestamp + EXPIRATION_INCREMENT;
        }

        // Transfer ownership and update token info
        _transfer(token.owner, msg.sender, _tokenId);
        token.owner = msg.sender;
        token.url = _url;
        token.expirationTimestamp = newExpiration;

        // Send royalty payment to the creator
        uint256 royaltyAmount = requiredPayment.mul(100 - REFUND_PERCENTAGE).div(200);
        (bool success, ) = token.creatorAddress.call{value: royaltyAmount}("");
        require(success, "Royalty payment failed");

        // Send the remaining payment to the treasury
        uint256 treasuryAmount = requiredPayment.sub(royaltyAmount);
        (success, ) = treasuryAddress.call{value: treasuryAmount}("");
        require(success, "Treasury payment failed");

        // Transfer governance tokens if available
        uint256 tokensToTransfer = msg.value.mul(ethToTokenRate);
        if (tokensToTransfer > 0) {
            IERC20(governanceTokenAddress).transfer(msg.sender, tokensToTransfer);
        }
    }

    function extendCoreTime(uint256 _numDays, uint256 _tokenId) external payable nonReentrant {
        require(_exists(_tokenId), "Token does not exist");
        require(msg.sender == tokenInfo[_tokenId].owner, "Only token owner can extend time");
        TokenInfo storage token = tokenInfo[_tokenId];
        uint256 currentPriceEth = getCurrentPriceETH(_tokenId);

        require(msg.value >= currentPriceEth, "Insufficient ETH payment");
        uint256 requiredPayment = msg.value;

        token.expirationTimestamp += (_numDays * 1 days);

        // Send royalty payment to the creator
        uint256 royaltyAmount = requiredPayment.mul(100 - REFUND_PERCENTAGE).div(200);
        (bool success, ) = token.creatorAddress.call{value: royaltyAmount}("");
        require(success, "Royalty payment failed");

        // Send the remaining payment to the treasury
        uint256 treasuryAmount = requiredPayment.sub(royaltyAmount);
        (success, ) = treasuryAddress.call{value: treasuryAmount}("");
        require(success, "Treasury payment failed");

        // Transfer governance tokens if available
        uint256 tokensToTransfer = msg.value.mul(ethToTokenRate);
        if (tokensToTransfer > 0) {
            IERC20(governanceTokenAddress).transfer(msg.sender, tokensToTransfer);
        }
    }

    function refundNFT(uint256 _tokenId) external nonReentrant {
        require(_exists(_tokenId), "Token does not exist");
        TokenInfo storage token = tokenInfo[_tokenId];
        require(msg.sender == token.owner, "Only token owner can refund");
        require(token.expirationTimestamp > 0, "Token has no expiration");

        uint256 refundAmount = getCurrentRefundAmount(_tokenId);
        require(refundAmount > 0, "No refund available");

        token.owner = address(0);
        token.expirationTimestamp = 0;

        (bool success, ) = msg.sender.call{value: refundAmount}("");
        require(success, "Refund failed");
    }

    function getCurrentPriceETH(uint256 _tokenId) internal view returns (uint256) {
        TokenInfo storage token = tokenInfo[_tokenId];
        
        if (totalSupply() == 0 || token.expirationTimestamp == 0) {
            return priceFloorEth;
        }

        return (token.expirationTimestamp - block.timestamp).mul(2).mul(priceFloorEth).div(1 days);
    }

    function getCurrentRefundAmount(uint256 _tokenId) internal view returns (uint256) {
        TokenInfo storage token = tokenInfo[_tokenId];
        require(token.expirationTimestamp > 0, "Token has no expiration");

        uint256 timeRemaining = token.expirationTimestamp - block.timestamp;
        uint256 refundAmount = msg.value.mul(REFUND_PERCENTAGE).mul(timeRemaining).div(1 days);

        return refundAmount;
    }


    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721Enumerable) {
        super._burn(tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function tokenURI(uint256 tokenId) public view override(ERC721) returns (string memory) {
        require(_exists(tokenId), "Token does not exist");
        return tokenInfo[tokenId].url;
    }

}
