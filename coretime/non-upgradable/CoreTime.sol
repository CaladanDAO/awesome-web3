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

    event CoreTimeBought(
        uint256 indexed tokenId,
        address indexed buyer,
        address indexed seller,
        string url,
        uint256 pricePaid,
        uint256 newExpiration,
        uint256 duration
    );

    event UrlUpdated(
        uint256 indexed tokenId,
        address indexed owner,
        string prevURL,
        string updatedURL
    );

    event coreTimeDistribution(
        uint256 indexed tokenId,
        address indexed owner,
        address token,
        uint256 tokenAmount
    );

    event coreTimeCompensated(
        uint256 indexed tokenId,
        address indexed previousOwner,
        address token,
        uint256 tokenAmount
    );

   event CoreTimeRefunded(
        uint256 indexed tokenId,
        address indexed owner,
        address token,
        uint256 tokenAmount
    );

    event RoyaltyPaid(
        uint256 indexed tokenId,
        address indexed creator,
        uint256 royaltyAmount
    );

    event TreasuryFunded(
        uint256 indexed tokenId,
        address indexed treasury,
        uint256 treasuryAmount
    );

    event CoreTimeExtended(
        uint256 indexed tokenId,
        address indexed owner,
        uint8 numDays,
        uint256 pricePerDay,
        uint256 pricePaid,
        uint256 newExpiration
    );

    event RoyaltyPaidForExtension(
        uint256 indexed tokenId,
        address indexed creator,
        uint8 numDays,
        uint256 royaltyAmount
    );

    event TreasuryFundedForExtension(
        uint256 indexed tokenId,
        address indexed treasury,
        uint8 numDays,
        uint256 treasuryAmount
    );

    struct TokenInfo {
        string url;
        uint256 expirationTimestamp;
        uint256 pricePerDay;
        address owner;
        address creatorAddress;
    }

    mapping(uint256 => TokenInfo) public tokenInfo;

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

    function mintNFT(uint256 _numTokens, address _creatorAddress)
        external
        onlyOwner
    {
        for (uint256 i = 0; i < _numTokens; i++) {
            uint256 tokenId = totalSupply() + 1;
            _mint(owner(), tokenId);
            tokenInfo[tokenId] = TokenInfo(
                "",
                0,
                priceFloorEth.div(EXPIRATION_INCREMENT * 1 days),
                owner(),
                _creatorAddress
            );
        }
    }

    function setUrl(uint256 _tokenId, string memory _url) external {
        require(_exists(_tokenId), "Token does not exist");
        require(
            msg.sender == tokenInfo[_tokenId].owner,
            "Only token owner can set URL"
        );

        // Store the previous URL
        string memory _prevURL = tokenInfo[_tokenId].url;

        // Update the URL
        tokenInfo[_tokenId].url = _url;

        // Emit the UrlUpdated event with both the previous and new URLs
        emit UrlUpdated(_tokenId, msg.sender, _prevURL, _url);
    }

    function getUrl(uint256 _tokenId) external view returns (string memory) {
        return tokenInfo[_tokenId].url;
    }

    function getTimeLeftBeforeExpiration(uint256 _tokenId)
        public
        view
        returns (uint256)
    {
        require(_exists(_tokenId), "Token does not exist");

        TokenInfo storage token = tokenInfo[_tokenId];

        if (token.expirationTimestamp > block.timestamp) {
            return token.expirationTimestamp - block.timestamp;
        } else {
            return 0;
        }
    }

    function buyCoreTime(uint256 _tokenId, string memory _url)
        external
        payable
        nonReentrant
    {
        require(_exists(_tokenId), "Token does not exist");
        require(msg.sender != address(0), "Invalid sender");
        TokenInfo storage token = tokenInfo[_tokenId];
        uint256 currentPriceEth = getCurrentPriceETH(_tokenId);

        require(msg.value >= currentPriceEth, "Insufficient ETH payment");

        uint256 requiredPayment = currentPriceEth;

        uint256 remainingTime = getTimeLeftBeforeExpiration(_tokenId);
        uint256 newExpiration = block.timestamp +
            (EXPIRATION_INCREMENT * 1 days) -
            remainingTime;
        uint256 duration = (EXPIRATION_INCREMENT * 1 days) - remainingTime;

        // If this is the first purchase, use the price floor
        if (currentPriceEth == 0) {
            require(
                requiredPayment >= priceFloorEth,
                "Price must be at least the floor price"
            );
        }

        if (
            token.expirationTimestamp != 0 &&
            block.timestamp < token.expirationTimestamp
        ) {
            require(
                token.expirationTimestamp >= newExpiration,
                "Buy forbidden"
            );
            // someone try to buy token from the user. In this case, prev users should be properly compensated
            uint256 prev_owner_payout = getTimeLeftBeforeExpiration(_tokenId)
                .mul(token.pricePerDay)
                .div((1 * 1 days));
            /*
            (bool isSuccess, ) = token.owner.call{value: prev_owner_payout}("");
            require(isSuccess, "PrevOwner payment failed");
            */
            // Compensate users with governance tokens if available
            uint256 tokensCompensation = prev_owner_payout.mul(ethToTokenRate);
            if (tokensCompensation > 0) {
                IERC20(governanceTokenAddress).transfer(
                    token.owner,
                    tokensCompensation
                );
                emit coreTimeCompensated(_tokenId, token.owner, governanceTokenAddress, tokensCompensation);
            }
        }

        // Send royalty payment to the creator
        uint256 royaltyAmount = requiredPayment
            .mul(100 - REFUND_PERCENTAGE)
            .div(200);
        (bool success, ) = token.creatorAddress.call{value: royaltyAmount}("");
        require(success, "Royalty payment failed");
        emit RoyaltyPaid(_tokenId, token.creatorAddress, royaltyAmount);

        // Send the remaining payment to the treasury
        uint256 treasuryAmount = requiredPayment.sub(royaltyAmount);
        (success, ) = treasuryAddress.call{value: treasuryAmount}("");
        require(success, "Treasury payment failed");
        emit TreasuryFunded(_tokenId, treasuryAddress, treasuryAmount);

        // Send the surplus payment back to the sender
        uint256 surplusPayment = msg.value.sub(currentPriceEth);
        (success, ) = msg.sender.call{value: surplusPayment}("");
        require(success, "Surplus payment failed");

        // Transfer governance tokens if available
        uint256 tokensDistribution = requiredPayment.mul(ethToTokenRate);
        if (tokensDistribution > 0) {
            IERC20(governanceTokenAddress).transfer(
                msg.sender,
                tokensDistribution
            );
            emit coreTimeDistribution(_tokenId, token.owner, governanceTokenAddress, tokensDistribution);
        }

        // Transfer ownership and update token info
        _transfer(token.owner, msg.sender, _tokenId);
        address _prevOwner = token.owner;
        token.owner = msg.sender;
        token.url = _url;
        token.pricePerDay = requiredPayment.mul(1 * 1 days).div(duration);
        token.expirationTimestamp = newExpiration;
        emit CoreTimeBought(
            _tokenId,
            msg.sender,
            _prevOwner,
            token.url,
            requiredPayment,
            newExpiration,
            duration
        );
    }

    function computeExtendCoreTime(uint8 _numDays, uint256 _tokenId)
        public
        view
        returns (uint256)
    {
        require(_exists(_tokenId), "Token does not exist");
        TokenInfo storage token = tokenInfo[_tokenId];
        uint256 pricePerDayEth = token.pricePerDay;
        return pricePerDayEth.mul(_numDays);
    }

    function extendCoreTime(uint8 _numDays, uint256 _tokenId)
        external
        payable
        nonReentrant
    {
        require(_exists(_tokenId), "Token does not exist");
        require(
            msg.sender == tokenInfo[_tokenId].owner,
            "Only token owner can extend time"
        );
        TokenInfo storage token = tokenInfo[_tokenId];
        uint256 requiredEth = computeExtendCoreTime(_numDays, _tokenId);

        require(
            msg.value >= requiredEth,
            string(
                abi.encodePacked(
                    "Insufficient ETH payment. Required: ",
                    uintToString(requiredEth),
                    ", Provided: ",
                    uintToString(msg.value)
                )
            )
        );

        uint256 requiredPayment = requiredEth;

        token.expirationTimestamp += (_numDays * 1 days);
        token.pricePerDay = requiredEth.div(_numDays);
        emit CoreTimeExtended(
            _tokenId,
            msg.sender,
            _numDays,
            token.pricePerDay,
            requiredPayment,
            token.expirationTimestamp
        );

        // Send royalty payment to the creator
        uint256 royaltyAmount = requiredPayment
            .mul(100 - REFUND_PERCENTAGE)
            .div(200);
        (bool success, ) = token.creatorAddress.call{value: royaltyAmount}("");
        require(success, "Royalty payment failed");
        emit RoyaltyPaidForExtension(
            _tokenId,
            token.creatorAddress,
            _numDays,
            royaltyAmount
        );

        // Send the remaining payment to the treasury
        uint256 treasuryAmount = requiredPayment.sub(royaltyAmount);
        (success, ) = treasuryAddress.call{value: treasuryAmount}("");
        require(success, "Treasury payment failed");
        emit TreasuryFundedForExtension(
            _tokenId,
            treasuryAddress,
            _numDays,
            treasuryAmount
        );

        // Refund surplus
        uint256 surplusAmount = msg.value.sub(requiredPayment);
        (success, ) = msg.sender.call{value: surplusAmount}("");
        require(success, "Surplus payment failed");

        // Transfer governance tokens if available
        uint256 tokensToTransfer = requiredPayment.mul(ethToTokenRate);
        if (tokensToTransfer > 0) {
            IERC20(governanceTokenAddress).transfer(
                msg.sender,
                tokensToTransfer
            );
        }
    }

    // Helper function to convert uint to string (this is a basic version; you can also use more sophisticated ones)
    function uintToString(uint256 v) internal pure returns (string memory str) {
        uint256 maxlength = 100;
        bytes memory reversed = new bytes(maxlength);
        uint256 i = 0;
        while (v != 0) {
            uint256 remainder = v % 10;
            v = v / 10;
            reversed[i++] = bytes1(uint8(48 + remainder));
        }
        bytes memory s = new bytes(i);
        for (uint256 j = 0; j < i; j++) {
            s[j] = reversed[i - 1 - j];
        }
        str = string(s);
    }

    function refundCoreTime(uint256 _tokenId) external nonReentrant {
        require(_exists(_tokenId), "Token does not exist");
        TokenInfo storage token = tokenInfo[_tokenId];
        require(msg.sender == token.owner, "Only token owner can refund");
        require(token.expirationTimestamp > 0, "Token has no expiration");

        uint256 refundAmount = getCurrentRefundAmount(_tokenId);
        require(refundAmount > 0, "No refund available");

        token.url = "";
        token.owner = address(0);
        token.expirationTimestamp = 0;

        // Refund as governance tokens
        uint256 tokensToTransfer = refundAmount.mul(ethToTokenRate);
        if (tokensToTransfer > 0) {
            IERC20(governanceTokenAddress).transfer(
                msg.sender,
                tokensToTransfer
            );
        }

        emit CoreTimeRefunded(
            _tokenId,
            msg.sender,
            governanceTokenAddress,
            refundAmount.mul(ethToTokenRate)
        );
    }

    // 2x of remaining days  * pricePerDay
    function getCurrentPriceETH(uint256 _tokenId)
        public
        view
        returns (uint256)
    {
        TokenInfo storage token = tokenInfo[_tokenId];

        if (
            totalSupply() == 0 ||
            token.expirationTimestamp == 0 ||
            block.timestamp > token.expirationTimestamp
        ) {
            return priceFloorEth;
        }

        return
            (token.expirationTimestamp - block.timestamp)
                .mul(2)
                .mul(token.pricePerDay)
                .div(1 days);
    }

    function getCurrentRefundAmount(uint256 _tokenId)
        internal
        view
        returns (uint256)
    {
        require(_exists(_tokenId), "Token does not exist");
        TokenInfo storage token = tokenInfo[_tokenId];
        if (
            block.timestamp > token.expirationTimestamp ||
            token.expirationTimestamp == 0
        ) {
            return 0;
        }

        uint256 pricePerDay = token.pricePerDay;
        uint256 timeRemaining = token.expirationTimestamp - block.timestamp;
        uint256 refundAmount = pricePerDay
            .mul(REFUND_PERCENTAGE)
            .mul(timeRemaining)
            .div(1 days);
        return refundAmount;
    }
}
