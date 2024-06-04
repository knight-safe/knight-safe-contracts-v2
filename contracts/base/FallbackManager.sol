// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.20;

import "../controlCenter/ControlCenter.sol";
import "../error/Errors.sol";

abstract contract FallbackManager {
    // keccak256("fallback_manager.handler.address")
    bytes32 private constant _FALLBACK_HANDLER_STORAGE_SLOT =
        0x6c9a6c4a39284e37ed1cf53d337577d14212a4870fb976a4366c693b939918d5;

    function _internalSetFallbackHandler(address handler) internal {
        if (handler == address(this)) revert Errors.InvalidAddress(handler);

        /* solhint-disable no-inline-assembly */
        /// @solidity memory-safe-assembly
        assembly {
            sstore(_FALLBACK_HANDLER_STORAGE_SLOT, handler)
        }
        /* solhint-enable no-inline-assembly */
    }

    // solhint-disable-next-line payable-fallback,no-complex-fallback
    fallback() external {
        /* solhint-disable no-inline-assembly */
        /// @solidity memory-safe-assembly
        assembly {
            // When compiled with the optimizer, the compiler relies on a certain assumptions on how the
            // memory is used, therefore we need to guarantee memory safety (keeping the free memory point 0x40 slot intact,
            // not going beyond the scratch space, etc)
            // Solidity docs: https://docs.soliditylang.org/en/latest/assembly.html#memory-safety

            let handler := sload(_FALLBACK_HANDLER_STORAGE_SLOT)

            if iszero(handler) { return(0, 0) }

            let ptr := mload(0x40)
            calldatacopy(ptr, 0, calldatasize())

            // The msg.sender address is shifted to the left by 12 bytes to remove the padding
            // Then the address without padding is stored right after the calldata
            mstore(add(ptr, calldatasize()), shl(96, caller()))

            // Add 20 bytes for the address appended add the end
            let success := call(gas(), handler, 0, ptr, add(calldatasize(), 20), 0, 0)

            returndatacopy(ptr, 0, returndatasize())
            if iszero(success) { revert(ptr, returndatasize()) }
            return(ptr, returndatasize())
        }
        /* solhint-enable no-inline-assembly */
    }
}
