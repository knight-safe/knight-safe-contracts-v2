// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import "../interfaces/IERC1271.sol";
import "../base/PolicyManager.sol";
import "../error/Errors.sol";
/**
 * @title SignatureValidator
 * @notice Implementation of ERC1271.
 */

abstract contract SignatureValidator is IERC1271, PolicyManager {
    using EnumerableSet for EnumerableSet.AddressSet;

    /**
     * @dev The signature derives the `address(0)`.
     */
    error ECDSAInvalidSignature();

    /**
     * @dev The signature has an S value that is in the upper half order.
     */
    error ECDSAInvalidSignatureS(bytes32 s);

    function isValidSignature(bytes32 _hash, bytes memory _signature) external view override returns (bytes4) {
        address signer = _recoverSigner(_hash, _signature);

        uint256[] memory policiyIds = getActivePolicyIds();
        // Validate signatures
        for (uint256 i = 0; i < policiyIds.length; i++) {
            if (isTrader(policiyIds[i], signer)) {
                return IERC1271.isValidSignature.selector;
            }
        }

        // Signer not a trader
        for (uint256 i = 0; i < policiyIds.length; i++) {
            EnumerableSet.AddressSet storage _traders = _policyMap[policiyIds[i]].traders;
            for (uint256 j = 0; j < _traders.length(); j++) {
                bytes4 magicValue = IERC1271(_traders.at(j)).isValidSignature(_hash, _signature);
                if (magicValue == IERC1271.isValidSignature.selector) {
                    return IERC1271.isValidSignature.selector;
                }
            }
        }

        return 0xffffffff;
    }

    /**
     * @notice Recover the signer of hash, assuming it's an EOA account
     * @dev Only for EthSign signatures
     * @param _hash       Hash of message that was signed
     * @param _signature  Signature encoded as (bytes32 r, bytes32 s, uint8 v)
     */
    function _recoverSigner(bytes32 _hash, bytes memory _signature) internal pure returns (address signer) {
        if (_signature.length != 65) revert Errors.InvalidLength();

        // Variables are not scoped in Solidity.
        bytes32 r;
        bytes32 s;
        uint8 v;
        /* solhint-disable no-inline-assembly */
        assembly {
            r := mload(add(_signature, 0x20))
            s := mload(add(_signature, 0x40))
            v := and(mload(add(_signature, 0x41)), 0xff)
        }

        if (uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) {
            revert ECDSAInvalidSignatureS(s);
        }

        // Recover ECDSA signer
        signer = ecrecover(_hash, v, r, s);

        // // Prevent signer from being 0x0
        if (signer == address(0)) {
            revert ECDSAInvalidSignature();
        }

        return signer;
    }
}
