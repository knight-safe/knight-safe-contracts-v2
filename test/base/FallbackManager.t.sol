// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./PolicyManager.t.sol";

import "@/mocks/MockERC721.sol";
import "@/mocks/MockERC1155.sol";

// This test file is used to test the FallbackManager
abstract contract FallbackManagerTest is PolicyManagerTest {
    function test_erc721() public {
        MockERC721 token = new MockERC721("mock", "mock");
        token.publicMint(ownerAddress, 0);

        assertTrue(token.ownerOf(0) == ownerAddress);

        token.approve(ownerAddress, 0);
        token.safeTransferFrom(ownerAddress, adminAddress, 0);
        assertFalse(token.ownerOf(0) == ownerAddress);
        assertTrue(token.ownerOf(0) == adminAddress);
    }

    function test_erc1155() public {
        MockERC1155 token = new MockERC1155("mock.uri");

        token.publicMint(ownerAddress, 0, 100);
        assertTrue(token.balanceOf(ownerAddress, 0) == 100);

        token.setApprovalForAll(ownerAddress, true);

        token.safeTransferFrom(ownerAddress, adminAddress, 0, 10, "");
        assertTrue(token.balanceOf(ownerAddress, 0) == 90);
        assertTrue(token.balanceOf(adminAddress, 0) == 90);
    }
}
