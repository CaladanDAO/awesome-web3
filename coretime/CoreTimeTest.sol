pragma solidity ^0.8.0;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/CoreTime.sol";

contract CoreTimeTest {
    CoreTime coreTime;
    uint256 tokenId;

    function beforeEach() public {
        coreTime = new CoreTime(
            address(this), // Use the test contract address as treasury
            1 ether,       // Price floor in ETH
            1000,          // ETH to token rate
            address(this)  // Governance token address
        );

        tokenId = 1;
        coreTime.mintNFT(1, address(this));
    }

    function testMintNFT() public {
        uint256 balance = coreTime.balanceOf(address(this));
        Assert.equal(balance, 1, "Should have 1 NFT after minting");
    }

    function testBuyCoreTime() public {
        uint256 initialBalance = address(this).balance;

        coreTime.buyCoreTime{value: 1.5 ether}(tokenId, "url");
        address owner = coreTime.ownerOf(tokenId);
        Assert.equal(owner, address(this), "Contract address should own the token");

        uint256 royaltyReceived = address(this).balance - initialBalance;
        Assert.isAbove(royaltyReceived, 0, "Should receive royalty payment");
    }

    function testExtendCoreTime() public {
        coreTime.extendCoreTime{value: 1 ether}(30, tokenId);
        uint256 newExpiration = coreTime.tokenInfo(tokenId).expirationTimestamp;
        Assert.isAbove(newExpiration, block.timestamp, "Should extend the expiration time");
    }

    function testRefundNFT() public {
        uint256 initialBalance = address(this).balance;

        coreTime.buyCoreTime{value: 1.5 ether}(tokenId, "url");
        uint256 refundAmount = coreTime.getCurrentRefundAmount(tokenId);
        coreTime.refundNFT(tokenId);

        uint256 finalBalance = address(this).balance;
        Assert.equal(finalBalance - initialBalance, refundAmount, "Should receive refund amount");
    }

    function testSetUrl() public {
        string memory newUrl = "new-url";
        coreTime.setUrl(tokenId, newUrl);
        Assert.equal(coreTime.getUrl(tokenId), newUrl, "Should set the new URL");
    }

    function testSetUrlOnlyOwner() public {
        string memory newUrl = "new-url";
        tokenId = 2;
        // Should fail since address(this) is not the token owner
        (bool success, ) = address(coreTime).call(abi.encodeWithSignature("setUrl(uint256,string)", tokenId, newUrl));
        Assert.isFalse(success, "Should fail since address(this) is not the token owner");
    }

    function testExtendCoreTimeOnlyOwner() public {
        tokenId = 2;
        // Should fail since address(this) is not the token owner
        (bool success, ) = address(coreTime).call(abi.encodeWithSignature("extendCoreTime(uint256,uint256)", 30, tokenId));
        Assert.isFalse(success, "Should fail since address(this) is not the token owner");
    }

    function testBuyCoreTimeInsufficientPayment() public {
        // Should fail since payment is insufficient
        (bool success, ) = address(coreTime).call{value: 0.5 ether}(abi.encodeWithSignature("buyCoreTime(uint256,string)", tokenId, "url"));
        Assert.isFalse(success, "Should fail since payment is insufficient");
    }

    function testExtendCoreTimeInsufficientPayment() public {
        // Should fail since payment is insufficient
        (bool success, ) = address(coreTime).call{value: 0.5 ether}(abi.encodeWithSignature("extendCoreTime(uint256,uint256)", 30, tokenId));
        Assert.isFalse(success, "Should fail since payment is insufficient");
    }

    function testBuyCoreTimeInvalidTokenId() public {
        uint256 invalidTokenId = 999;
        // Should fail since tokenId doesn't exist
        (bool success, ) = address(coreTime).call{value: 1.5 ether}(abi.encodeWithSignature("buyCoreTime(uint256,string)", invalidTokenId, "url"));
        Assert.isFalse(success, "Should fail since tokenId doesn't exist");
    }

    function testRefundNFTInvalidTokenId() public {
        uint256 invalidTokenId = 999;
        // Should fail since tokenId doesn't exist
        (bool success, ) = address(coreTime).call(abi.encodeWithSignature("refundNFT(uint256)", invalidTokenId));
        Assert.isFalse(success, "Should fail since tokenId doesn't exist");
    }

    function testRefundNFTNotTokenOwner() public {
        tokenId = 2;
        // Should fail since address(this) is not the token owner
        (bool success, ) = address(coreTime).call(abi.encodeWithSignature("refundNFT(uint256)", tokenId));
        Assert.isFalse(success, "Should fail since address(this) is not the token owner");
    }

    function testRefundNFTNoExpiration() public {
        tokenId = 2;
        // Should fail since token has no expiration
        (bool success, ) = address(coreTime).call(abi.encodeWithSignature("refundNFT(uint256)", tokenId));
        Assert.isFalse(success, "Should fail since token has no expiration");
    }
}
