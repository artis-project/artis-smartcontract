// SPDX-License-Identifier: GPL-3.0
        
pragma solidity >=0.4.22 <0.9.0;

// This import is automatically injected by Remix
import "remix_tests.sol"; 

// This import is required to use custom transaction context
// Although it may fail compilation in 'Solidity Compiler' plugin
// But it will work fine in 'Solidity Unit Testing' plugin
import "remix_accounts.sol";
import "../contracts/artwork.sol";

// File name has to end with '_test.sol', this file can contain more than one testSuite contracts
contract testSuite is Artwork {

    address RPC_wallet;
    address first_owner_wallet;

    function beforeAll() public {
        RPC_wallet = TestsAccounts.getAccount(0);
        first_owner_wallet = TestsAccounts.getAccount(1);
    }
    
    function checkAdminAddress() public {
        Assert.equal(msg.sender, RPC_wallet, "sender should be RPC wallet");
        Assert.equal(msg.sender, smartcontractAdmin, "Sender did not get assigned to ADMIN");
    }

    function testMint() public {
        uint256 tokenId = safeMint(first_owner_wallet);
        Assert.equal(tokenId, 0, "first tokenID should be 0");
        Assert.equal(balanceOf(first_owner_wallet), 1, "owner#1 wallet should hold 1 token");
        Assert.equal(ownerOf(tokenId), first_owner_wallet, "owner#1 wallet should be owner of first token");
    }

    function testMetadata() public {
        Assert.equal(artworks[0].id, 0, "should be equal");
        Assert.equal(artworks[0].carrier, address(0), "should be equal");
        Assert.equal(artworks[0].logger, address(0), "should be equal");
        Assert.equal(artworks[0].recipient, address(0), "should be equal");
        Assert.equal(artworks[0].status, "MINTED", "should be equal");
        Assert.equal(artworks[0].status, "MINTED", "should be equal");
        Assert.equal(artworks[0].temperatureViolation, false, "should be equal");
        Assert.equal(artworks[0].humidityViolation, false, "should be equal");
    }


}
    