// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.9.0;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

/// @notice This is a mock contract of the ERC721 standard for testing purposes only, it SHOULD NOT be used in production.
/// @dev Forked from: https://github.com/transmissions11/solmate/blob/0384dbaaa4fcb5715738a9254a7c0a4cb62cf458/src/tokens/ERC721.sol
contract MockERC1155 is ERC1155 {
    /*//////////////////////////////////////////////////////////////
                         METADATA STORAGE/LOGIC
    //////////////////////////////////////////////////////////////*/

    constructor(string memory uri_) ERC1155(uri_) {}

    function publicMint(address to, uint256 id, uint256 value) public {
        _mint(to, id, value, "");
    }
}
