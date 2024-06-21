// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {KnightSafeProxy} from "./KnightSafeProxy.sol";
import {ProxyFactoryEventUtils} from "./ProxyFactoryEventUtils.sol";
import {ControlCenter} from "../controlCenter/ControlCenter.sol";
import "@/error/Errors.sol";

/**
 * @title KnightSafeProxyFactory
 * @notice A factory contract that allow user to create new KnightSafeProxy contract
 */
contract KnightSafeProxyFactory {
    error Create2EmptyBytecode();

    ControlCenter public immutable CONTROL_CENTER;

    constructor(address controlCenterAddress) {
        CONTROL_CENTER = ControlCenter(controlCenterAddress);
    }

    /**
     * @notice Compute the address of a new proxy contract
     * @dev Returns the address where a contract will be stored if deployed via {deploy} from a contract located at
     * `deployer`. If `deployer` is this contract's address, returns the same value as {computeAddress}.
     * @param saltNonce Nonce that will be used to generate the salt to calculate the address of the new proxy contract.
     * @param implementation Address of implementation contract
     */
    function computeAddress(uint256 saltNonce, address implementation) external view returns (address addr) {
        address contractAddress = address(this);
        bytes32 creationCodeHash =
            keccak256(abi.encodePacked(type(KnightSafeProxy).creationCode, uint256(uint160(address(implementation)))));
        bytes32 salt = keccak256(abi.encodePacked(saltNonce));
        /* solhint-disable no-inline-assembly */
        assembly {
            let ptr := mload(0x40)

            mstore(add(ptr, 0x40), creationCodeHash)
            mstore(add(ptr, 0x20), salt)
            mstore(ptr, contractAddress)
            let start := add(ptr, 0x0b)
            mstore8(start, 0xff)
            addr := keccak256(start, 85)
        }
    }

    /**
     * @notice Create a new KnightSafeProxy contract
     * @param implementation Address of implementation contract
     * @param data Payload for a message call to be sent to a new proxy contract
     * @param saltNonce Nonce that will be used to generate the salt to calculate the address of the new proxy contract.
     */
    function createProxy(address implementation, bytes memory data, uint256 saltNonce)
        public
        returns (KnightSafeProxy proxy)
    {
        if (implementation == address(0)) revert Errors.IsNullValue();
        if (!CONTROL_CENTER.isOfficialImplementation(implementation)) {
            revert Errors.AddressIsNotKnightSafeImplementation(implementation);
        }
        bytes32 salt = keccak256(abi.encodePacked(saltNonce));
        proxy = _deployProxy(implementation, data, salt);

        ProxyFactoryEventUtils.emitProxyCreation(CONTROL_CENTER, implementation, address(proxy), msg.sender, saltNonce);
    }

    function _deployProxy(address implementation, bytes memory data, bytes32 salt)
        private
        returns (KnightSafeProxy proxy)
    {
        bytes memory bytecodeHash =
            abi.encodePacked(type(KnightSafeProxy).creationCode, uint256(uint160(implementation)));
        if (bytecodeHash.length == 0) {
            revert Create2EmptyBytecode();
        }
        /* solhint-disable no-inline-assembly */
        assembly {
            proxy := create2(callvalue(), add(bytecodeHash, 0x20), mload(bytecodeHash), salt)
        }

        if (address(proxy) == address(0)) {
            revert Errors.FailedDeployment();
        }

        CONTROL_CENTER.setActiveAccount(address(proxy));
        if (data.length > 0) {
            /* solhint-disable no-inline-assembly */
            assembly {
                if eq(call(gas(), proxy, 0, add(data, 0x20), mload(data), 0, 0), 0) { revert(0, 0) }
            }
        }
    }
}
