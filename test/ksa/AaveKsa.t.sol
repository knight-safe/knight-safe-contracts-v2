// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "forge-std/mocks/MockERC20.sol";
import {UniswapAnalyser, Commands} from "@/knightSafeAnalyser/UniswapAnalyser.sol";
import {ERC20Analyser} from "@/knightSafeAnalyser/ERC20Analyser.sol";
import {AaveAnalyser} from "@/knightSafeAnalyser/AaveAnalyser.sol";
import {AaveUtilsAnalyser} from "@/knightSafeAnalyser/AaveUtilsAnalyser.sol";
import "@/controlCenter/ControlCenter.sol";

contract AaveAnalyserTest is Test {
    AaveUtilsAnalyser ksa;
    ControlCenter controlCenter;

    address mockAddress = address(0x10001); // any address
    address mockNative = address(0x1111111111111); // any address
    address internal ownerAddress = address(this);

    function setUp() public {
        ksa = new AaveUtilsAnalyser(mockNative);
        controlCenter = new ControlCenter(ownerAddress);
        IControlCenter(controlCenter).addOfficialAnalyser(address(ksa), "ave_0.1");

        assertEq(IControlCenter(controlCenter).isOfficialAnalyser(address(ksa)), true);
    }

    // function test_function() public {
    //     // solhint-disable-next-line
    //     bytes memory data =
    //         hex"236300dc0000000000000000000000000000000000000000000000000000000000000080ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000e843f3f2298c64610b9c0d390378a0c32a448893000000000000000000000000912ce59144191c1204e64559fe8253a0e49e65480000000000000000000000000000000000000000000000000000000000000001000000000000000000000000724dc807b04555b71ed48a6896b6f41593b8c637";

    //     (address[] memory addrList, uint256[] memory valueList) = ksa.extractAddressesWithValue(mockAddress, data);
    //     console.log(addrList.length);
    //     for (uint256 i = 0; i < addrList.length; i++) {
    //         console.log("addrList[", i, "]: ", addrList[i]);
    //         console.log("valueList[", i, "]: ", valueList[i]);
    //     }
    // }

    function test_function1() public {
        // solhint-disable-next-line
        bytes memory data =
            hex"80500d20000000000000000000000000794a61358d6845594f94dc1db02a252b5b4814ad00000000000000000000000000000000000000000000000000356a8bf4c801e700000000000000000000000092f0e575ce0839f4e5702b30ac72546adce2320f";

        (address[] memory addrList, uint256[] memory valueList) = ksa.extractAddressesWithValue(mockAddress, data);
        console.log(addrList.length);
        for (uint256 i = 0; i < addrList.length; i++) {
            console.log("addrList[", i, "]: ", addrList[i]);
            console.log("valueList[", i, "]: ", valueList[i]);
        }
    }

    function getSelector(bytes memory data) public pure returns (bytes4 selector) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            selector := mload(add(data, add(0x20, 0)))
        }
    }

    function getCommands(bytes calldata data) public pure returns (bytes calldata commands) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            let dataOffset := add(data.offset, 4)

            let commandsOffset := calldataload(dataOffset)
            commands.offset := add(add(dataOffset, commandsOffset), 0x20)
            commands.length := calldataload(add(dataOffset, commandsOffset))
        }
    }
}

// $ yarn test --match-contract AaveAnalyserTest
