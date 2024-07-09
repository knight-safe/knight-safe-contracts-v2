// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import {BaseKnightSafeAnalyser} from "./BaseKnightSafeAnalyser.sol";
import "../interfaces/IKnightSafeAnalyser.sol";

contract UniswapAnalyser is BaseKnightSafeAnalyser {
    error FeeTooHigh();

    event MaxFeeBipsUpdated(uint256 feeBips);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    address public immutable nativeToken;
    address public immutable owner;
    uint256 public maxFeeBips;

    constructor(address nativeToken_, address owner_) {
        owner = owner_;
        nativeToken = nativeToken_;
        maxFeeBips = 15;
    }

    modifier onlyOwner() {
        if (owner != msg.sender) revert Unauthorized("OWNER");
        _;
    }

    function updateMaxFeeBips(uint256 newMaxFeeBips) public onlyOwner {
        maxFeeBips = newMaxFeeBips;
        emit MaxFeeBipsUpdated(maxFeeBips);
    }

    /// @inheritdoc IKnightSafeAnalyser
    function extractAddressesWithValue(address to, bytes calldata data)
        external
        view
        override
        returns (address[] memory addrList, uint256[] memory valueList)
    {
        bytes4 selector = getSelector(data);

        (addrList, valueList) = _getAddressListForChecking(to, selector, data);
    }

    function _getAddressListForChecking(address to, bytes4 selector, bytes calldata data)
        private
        view
        returns (address[] memory addrList, uint256[] memory valueList)
    {
        if (
            selector == 0x24856bc3 // execute(commands:bytes,inputs:bytes[])
                || selector == 0x3593564c // execute(commands:bytes,inputs:bytes[],deadline:uint256)
        ) {
            bytes calldata commands;
            bytes[] calldata inputs;
            /* solhint-disable no-inline-assembly */
            assembly {
                let dataOffset := add(data.offset, 4)

                let commandsOffset := calldataload(dataOffset)
                commands.offset := add(add(dataOffset, commandsOffset), 0x20)
                commands.length := calldataload(add(dataOffset, commandsOffset))

                let inputsOffset := calldataload(add(dataOffset, 0x20))
                inputs.offset := add(add(dataOffset, inputsOffset), 0x20)
                inputs.length := calldataload(add(dataOffset, inputsOffset))
            }

            (addrList, valueList) = _getAddressArrayFromExecute(commands, inputs, to);
            if (addrList.length == 0) {
                // in case all check is valid but no address to check, we return "to" instead of empty array
                addrList = new address[](1);
                valueList = new uint256[](addrList.length);

                addrList[0] = to;
                valueList[0] = 0;
            }
            return (addrList, valueList);
        } else if (
            selector == 0x87517c45 // approve(token:address,spender:address,amount:uint160,expiration:uint48)
                || selector == 0x8b5a3d3b //  invalidateNonces(token:address,spender:address,newNonce:uint48)
        ) {
            //  Permit 2 below
            addrList = new address[](2);
            addrList[0] = _getAddressFromBytes(data, 0); // token
            addrList[1] = _getAddressFromBytes(data, 1); // spender
            valueList = new uint256[](addrList.length);
            valueList[0] = 0;
            valueList[1] = 0;
            return (addrList, valueList);
        } else if (
            selector == 0x36c78516 // transferFrom(from:address,to:address,amount:uint160,token:address)
        ) {
            addrList = new address[](3);
            addrList[0] = _getAddressFromBytes(data, 0); // from
            addrList[1] = _getAddressFromBytes(data, 1); // to
            addrList[2] = _getAddressFromBytes(data, 3); // token
            valueList = new uint256[](addrList.length);
            valueList[0] = 0;
            valueList[1] = 0;
            valueList[2] = _getUintFromBytes(data, 2);
            return (addrList, valueList);
        } else if (
            selector == 0x3ff9dcb1 //  invalidateUnorderedNonces(wordPos:uint256,mask:uint256)
        ) {
            addrList = new address[](1);
            addrList[0] = to; // to
            valueList = new uint256[](addrList.length);
            valueList[0] = 0;
            return (addrList, valueList);
        }

        revert UnsupportedCommand();
    }

    function _getAddressArrayFromExecute(bytes calldata commands, bytes[] calldata inputs, address to)
        private
        view
        returns (address[] memory addrList, uint256[] memory valueList)
    {
        address[][] memory _addressArrays = new address[][](commands.length);
        uint256[][] memory _uintArrays = new uint256[][](commands.length);
        uint256 _addressCount = 0;
        uint256 _totalBips = 0;
        for (uint256 i = 0; i < commands.length; i++) {
            (address[] memory _addressArray, uint256[] memory _uintArray, uint256 bips) =
                _dispatch(commands[i], inputs[i]);
            _addressCount += _addressArray.length;
            _addressArrays[i] = _addressArray;
            _uintArrays[i] = _uintArray;
            _totalBips += bips;
        }

        if (_totalBips > maxFeeBips) {
            revert FeeTooHigh();
        }

        addrList = new address[](_addressCount);
        valueList = new uint256[](_addressCount);
        uint256 x = 0;
        for (uint256 i = 0; i < _addressArrays.length; i++) {
            for (uint256 j = 0; j < _addressArrays[i].length; j++) {
                addrList[x] = _map(_addressArrays[i][j], to);
                valueList[x] = _uintArrays[i][j];
                x++;
            }
        }
    }

    function _dispatch(bytes1 commandType, bytes calldata inputs)
        private
        view
        returns (address[] memory addrList, uint256[] memory valueList, uint256 bips)
    {
        uint256 command = uint8(commandType & Commands.COMMAND_TYPE_MASK);

        if (command == Commands.V3_SWAP_EXACT_IN) {
            // equivalent: abi.decode(inputs, (address, uint256, uint256, bytes, bool))
            address recipient;
            uint256 amountIn;
            bool payerIsUser;

            /* solhint-disable no-inline-assembly */
            assembly {
                recipient := calldataload(inputs.offset)
                amountIn := calldataload(add(inputs.offset, 0x20))
                payerIsUser := calldataload(add(inputs.offset, 0x80))
            }
            bytes calldata path = _toBytes(inputs, 3);
            (address token0, address token1) = _toPathTokensV3(path);
            if (!payerIsUser) {
                addrList = new address[](2);
                valueList = new uint256[](addrList.length);
                addrList[0] = recipient;
                addrList[1] = token1;

                valueList[0] = 0;
                valueList[1] = 0;
            } else if (recipient == address(1)) {
                addrList = new address[](2);
                valueList = new uint256[](addrList.length);

                addrList[0] = token0;
                addrList[1] = token1;
                valueList[0] = amountIn;
                valueList[1] = 0;
            } else if (recipient == address(2)) {
                addrList = new address[](1);
                valueList = new uint256[](addrList.length);

                addrList[0] = token0;
                valueList[0] = amountIn;
            } else {
                addrList = new address[](3);
                valueList = new uint256[](addrList.length);

                addrList[0] = recipient;
                addrList[1] = token0;
                addrList[2] = token1;
                valueList[0] = 0;
                valueList[1] = amountIn;
                valueList[2] = 0;
            }
            return (addrList, valueList, bips);
        } else if (command == Commands.V2_SWAP_EXACT_IN) {
            // equivalent: abi.decode(inputs, (address, uint256, uint256, bytes, bool))
            address recipient;
            uint256 amountIn;
            bool payerIsUser;

            /* solhint-disable no-inline-assembly */
            assembly {
                recipient := calldataload(inputs.offset)
                amountIn := calldataload(add(inputs.offset, 0x20))
                payerIsUser := calldataload(add(inputs.offset, 0x80))
            }
            bytes calldata path = _toBytes(inputs, 3);
            (address token0, address token1) = _toPathTokensV2(path);
            if (!payerIsUser) {
                addrList = new address[](2);
                valueList = new uint256[](addrList.length);

                addrList[0] = recipient;
                addrList[1] = token1;
                valueList[0] = 0;
                valueList[1] = 0;
            } else if (recipient == address(1)) {
                addrList = new address[](2);
                valueList = new uint256[](addrList.length);

                addrList[0] = token0;
                addrList[1] = token1;
                valueList[0] = amountIn;
                valueList[1] = 0;
            } else if (recipient == address(2)) {
                addrList = new address[](1);
                valueList = new uint256[](addrList.length);

                addrList[0] = token0;
                valueList[0] = amountIn;
            } else {
                addrList = new address[](3);
                valueList = new uint256[](addrList.length);

                addrList[0] = recipient;
                addrList[1] = token0;
                addrList[2] = token1;
                valueList[0] = 0;
                valueList[1] = amountIn;
                valueList[2] = 0;
            }
            return (addrList, valueList, bips);
        } else if (command == Commands.V3_SWAP_EXACT_OUT) {
            // equivalent: abi.decode(inputs, (address, uint256, uint256, bytes, bool))
            address recipient;
            uint256 amountOut;
            bool payerIsUser;

            /* solhint-disable no-inline-assembly */
            assembly {
                recipient := calldataload(inputs.offset)
                amountOut := calldataload(add(inputs.offset, 0x20))
                payerIsUser := calldataload(add(inputs.offset, 0x80))
            }
            bytes calldata path = _toBytes(inputs, 3);
            (address token0, address token1) = _toPathTokensV3(path);
            if (!payerIsUser) {
                addrList = new address[](2);
                valueList = new uint256[](addrList.length);

                addrList[0] = recipient;
                addrList[1] = token1;
                valueList[0] = 0;
                valueList[1] = amountOut;
            } else if (recipient == address(1)) {
                addrList = new address[](2);
                valueList = new uint256[](addrList.length);
                addrList[0] = token0;
                addrList[1] = token1;
                valueList[0] = 0;
                valueList[1] = amountOut;
            } else if (recipient == address(2)) {
                addrList = new address[](1);
                valueList = new uint256[](addrList.length);

                addrList[0] = token1;
                valueList[0] = amountOut;
            } else {
                addrList = new address[](3);
                valueList = new uint256[](addrList.length);

                addrList[0] = recipient;
                addrList[1] = token0;
                addrList[2] = token1;
                valueList[0] = 0;
                valueList[1] = 0;
                valueList[2] = amountOut;
            }
            return (addrList, valueList, bips);
        } else if (command == Commands.V2_SWAP_EXACT_OUT) {
            // equivalent: abi.decode(inputs, (address, uint256, uint256, bytes, bool))
            address recipient;
            uint256 amountOut;
            bool payerIsUser;

            /* solhint-disable no-inline-assembly */
            assembly {
                recipient := calldataload(inputs.offset)
                amountOut := calldataload(add(inputs.offset, 0x20))
                payerIsUser := calldataload(add(inputs.offset, 0x80))
            }
            bytes calldata path = _toBytes(inputs, 3);
            (address token0, address token1) = _toPathTokensV2(path);
            if (!payerIsUser) {
                addrList = new address[](2);
                valueList = new uint256[](addrList.length);

                addrList[0] = recipient;
                addrList[1] = token1;
                valueList[0] = 0;
                valueList[1] = amountOut;
            } else if (recipient == address(1)) {
                addrList = new address[](2);
                valueList = new uint256[](addrList.length);
                addrList[0] = token0;
                addrList[1] = token1;
                valueList[0] = 0;
                valueList[1] = amountOut;
            } else if (recipient == address(2)) {
                addrList = new address[](1);
                valueList = new uint256[](addrList.length);

                addrList[0] = token1;
                valueList[0] = amountOut;
            } else {
                addrList = new address[](3);
                valueList = new uint256[](addrList.length);

                addrList[0] = recipient;
                addrList[1] = token0;
                addrList[2] = token1;
                valueList[0] = 0;
                valueList[1] = 0;
                valueList[2] = amountOut;
            }
            return (addrList, valueList, bips);
        } else if (
            command == Commands.PERMIT2_TRANSFER_FROM || command == Commands.SWEEP || command == Commands.TRANSFER
        ) {
            // equivalent:  abi.decode(inputs, (address, address, uintxxx))
            address token;
            address recipient;
            uint160 amount;

            /* solhint-disable no-inline-assembly */
            assembly {
                token := calldataload(inputs.offset)
                recipient := calldataload(add(inputs.offset, 0x20))
                amount := calldataload(add(inputs.offset, 0x40))
            }
            addrList = new address[](2);
            valueList = new uint256[](addrList.length);

            addrList[0] = recipient;
            addrList[1] = token;
            valueList[0] = 0;
            valueList[1] = amount;
            return (addrList, valueList, bips);
        } else if (command == Commands.PAY_PORTION) {
            // equivalent:  abi.decode(inputs, (address, address, uintxxx))
            address token;
            assembly {
                token := calldataload(inputs.offset)
                bips := calldataload(add(inputs.offset, 0x40))
            }
            addrList = new address[](2);
            addrList[0] = token;
            addrList[1] = nativeToken;
            valueList = new uint256[](addrList.length);
            valueList[0] = 0;
            valueList[1] = bips;
            return (addrList, valueList, bips);
        } else if (command == Commands.PERMIT2_PERMIT_BATCH) {
            (PermitBatch memory permitBatch,) = abi.decode(inputs, (PermitBatch, bytes));
            addrList = new address[](permitBatch.details.length + 1);
            valueList = new uint256[](addrList.length);

            for (uint256 i = 0; i < permitBatch.details.length; i++) {
                addrList[i] = permitBatch.details[i].token;
                valueList[i] = 0;
            }
            addrList[permitBatch.details.length] = permitBatch.spender;
            valueList[permitBatch.details.length] = 0;
            return (addrList, valueList, bips);
        } else if (command == Commands.PERMIT2_PERMIT) {
            // equivalent: abi.decode(inputs, (IAllowanceTransfer.PermitSingle, bytes))
            PermitSingle calldata permitSingle;

            /* solhint-disable no-inline-assembly */
            assembly {
                permitSingle := inputs.offset
            }
            addrList = new address[](2);
            valueList = new uint256[](addrList.length);

            addrList[0] = permitSingle.spender;
            addrList[1] = permitSingle.details.token;
            valueList[0] = 0;
            valueList[1] = 0;
            return (addrList, valueList, bips);
        } else if (command == Commands.WRAP_ETH || command == Commands.UNWRAP_WETH) {
            // equivalent: abi.decode(inputs, (address, uint256))
            address recipient;
            uint256 amountMin;
            /* solhint-disable no-inline-asembly */
            assembly {
                recipient := calldataload(inputs.offset)
                amountMin := calldataload(add(inputs.offset, 0x20))
            }
            addrList = new address[](2);
            valueList = new uint256[](addrList.length);

            addrList[0] = recipient;
            addrList[1] = nativeToken;
            valueList[0] = 0;
            valueList[1] = 0;
            return (addrList, valueList, bips);
        } else if (command == Commands.PERMIT2_TRANSFER_FROM_BATCH) {
            (AllowanceTransferDetails[] memory batchDetails) = abi.decode(inputs, (AllowanceTransferDetails[]));
            addrList = new address[](batchDetails.length * 2);
            valueList = new uint256[](addrList.length);

            uint256 x = 0;
            for (uint256 i = 0; i < batchDetails.length; i++) {
                addrList[x] = batchDetails[i].to;
                valueList[x++] = 0;
                addrList[x] = batchDetails[i].token;
                valueList[x++] = batchDetails[i].amount;
            }
            return (addrList, valueList, bips);
        }

        revert UnsupportedCommand();
    }

    function _toPathTokensV3(bytes calldata _bytes) internal pure returns (address token0, address token1) {
        /* solhint-disable no-inline-assembly */
        assembly {
            let firstWord := calldataload(_bytes.offset)
            token0 := shr(96, firstWord)
            token1 := shr(96, calldataload(sub(add(_bytes.offset, _bytes.length), 20)))
        }
    }

    function _toPathTokensV2(bytes calldata _bytes) internal pure returns (address token0, address token1) {
        /* solhint-disable no-inline-assembly */
        assembly {
            token0 := calldataload(_bytes.offset)
            token1 := calldataload(add(_bytes.offset, shl(5, sub(_bytes.length, 1))))
        }
    }

    function _toBytes(bytes calldata _bytes, uint256 _arg) internal pure returns (bytes calldata res) {
        /* solhint-disable no-inline-assembly */
        assembly {
            let lengthPtr := add(_bytes.offset, calldataload(add(_bytes.offset, shl(5, _arg))))
            res.length := calldataload(lengthPtr)
            res.offset := add(lengthPtr, 0x20)
        }
    }

    function _map(address recipient, address to) internal view returns (address) {
        if (recipient == address(1)) {
            return msg.sender;
        } else if (recipient == address(2)) {
            return to; //uniswap
        } else {
            return recipient;
        }
    }

    struct PermitDetails {
        // ERC20 token address
        address token;
        // the maximum amount allowed to spend
        uint160 amount;
        // timestamp at which a spender's token allowances become invalid
        uint48 expiration;
        // an incrementing value indexed per owner,token,and spender for each signature
        uint48 nonce;
    }

    /// @notice The permit message signed for a single token allownce
    struct PermitSingle {
        // the permit data for a single token alownce
        PermitDetails details;
        // address permissioned on the allowed tokens
        address spender;
        // deadline on the permit signature
        uint256 sigDeadline;
    }

    /// @notice The permit message signed for multiple token allowances
    struct PermitBatch {
        // the permit data for multiple token allowances
        PermitDetails[] details;
        // address permissioned on the allowed tokens
        address spender;
        // deadline on the permit signature
        uint256 sigDeadline;
    }

    struct AllowanceTransferDetails {
        // the owner of the token
        address from;
        // the recipient of the token
        address to;
        // the amount of the token
        uint160 amount;
        // the token to be transferred
        address token;
    }
}

library Commands {
    // Masks to extract certain bits of commands
    bytes1 internal constant FLAG_ALLOW_REVERT = 0x80;
    bytes1 internal constant COMMAND_TYPE_MASK = 0x3f;

    // Command Types. Maximum supported command at this moment is 0x3f.

    // Command Types where value<0x08, executed in the first nested-if block
    uint256 internal constant V3_SWAP_EXACT_IN = 0x00;
    uint256 internal constant V3_SWAP_EXACT_OUT = 0x01;
    uint256 internal constant PERMIT2_TRANSFER_FROM = 0x02;
    uint256 internal constant PERMIT2_PERMIT_BATCH = 0x03;
    uint256 internal constant SWEEP = 0x04;
    uint256 internal constant TRANSFER = 0x05;
    uint256 internal constant PAY_PORTION = 0x06;
    // COMMAND_PLACEHOLDER = 0x07;

    // The commands are executed in nested if blocks to minimise gas consumption
    // The following constant defines one of the boundaries where the if blocks split commands
    uint256 internal constant FIRST_IF_BOUNDARY = 0x08;

    // Command Types where 0x08<=value<=0x0f, executed in the second nested-if block
    uint256 internal constant V2_SWAP_EXACT_IN = 0x08;
    uint256 internal constant V2_SWAP_EXACT_OUT = 0x09;
    uint256 internal constant PERMIT2_PERMIT = 0x0a;
    uint256 internal constant WRAP_ETH = 0x0b;
    uint256 internal constant UNWRAP_WETH = 0x0c;
    uint256 internal constant PERMIT2_TRANSFER_FROM_BATCH = 0x0d;
    uint256 internal constant BALANCE_CHECK_ERC20 = 0x0e;
    // COMMAND_PLACEHOLDER = 0x0f;

    // The commands are executed in nested if blocks to minimise gas consumption
    // The following constant defines one of the boundaries where the if blocks split commands
    uint256 internal constant SECOND_IF_BOUNDARY = 0x10;

    // Command Types where 0x10<=value<0x18, executed in the third nested-if block
    uint256 internal constant SEAPORT_V1_5 = 0x10;
    uint256 internal constant LOOKS_RARE_V2 = 0x11;
    uint256 internal constant NFTX = 0x12;
    uint256 internal constant CRYPTOPUNKS = 0x13;
    // 0x14;
    uint256 internal constant OWNER_CHECK_721 = 0x15;
    uint256 internal constant OWNER_CHECK_1155 = 0x16;
    uint256 internal constant SWEEP_ERC721 = 0x17;

    // The commands are executed in nested if blocks to minimise gas consumption
    // The following constant defines one of the boundaries where the if blocks split commands
    uint256 internal constant THIRD_IF_BOUNDARY = 0x18;

    // Command Types where 0x18<=value<=0x1f, executed in the final nested-if block
    uint256 internal constant X2Y2_721 = 0x18;
    uint256 internal constant SUDOSWAP = 0x19;
    uint256 internal constant NFT20 = 0x1a;
    uint256 internal constant X2Y2_1155 = 0x1b;
    uint256 internal constant FOUNDATION = 0x1c;
    uint256 internal constant SWEEP_ERC1155 = 0x1d;
    uint256 internal constant ELEMENT_MARKET = 0x1e;
    // COMMAND_PLACEHOLDER = 0x1f;

    // The commands are executed in nested if blocks to minimise gas consumption
    // The following constant defines one of the boundaries where the if blocks split commands
    uint256 internal constant FOURTH_IF_BOUNDARY = 0x20;

    // Command Types where 0x20<=value
    uint256 internal constant SEAPORT_V1_4 = 0x20;
    uint256 internal constant EXECUTE_SUB_PLAN = 0x21;
    uint256 internal constant APPROVE_ERC20 = 0x22;
    // COMMAND_PLACEHOLDER for 0x23 to 0x3f (all unused)
}
