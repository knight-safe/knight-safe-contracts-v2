// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "forge-std/mocks/MockERC20.sol";
import "../../contracts/knightSafeAnalyser/ERC20Analyser.sol";
import "../../contracts/controlCenter/ControlCenter.sol";

contract ERC20AnalyserTest is Test {
    ERC20Analyser ksa;
    ControlCenter controlCenter;
    address mockToken = address(0x10001);
    address internal ownerAddress = address(this);

    function setUp() public {
        ksa = new ERC20Analyser();
        controlCenter = new ControlCenter(ownerAddress);
        IControlCenter(controlCenter).addOfficialAnalyser(address(ksa), "ksa_0.01");

        assertEq(IControlCenter(controlCenter).isOfficialAnalyser(address(ksa)), true);
    }

    function test_ksaApprove() public {
        bytes memory data = abi.encodePacked(MockERC20.approve.selector, abi.encode(address(0x2), uint256(10000))); // mock erc20 transfer

        (address[] memory addrList, uint256[] memory valueList) = ksa.extractAddressesWithValue(mockToken, data);

        assertEq(addrList.length, 2);
        assertEq(valueList.length, 2);
        assertEq(address(0x2), address(addrList[0]));
        assertEq(mockToken, address(addrList[1]));
        assertEq(0, valueList[0]);
        assertEq(0, valueList[1]);
    }

    function test_ksaTransfer() public {
        bytes memory data = abi.encodePacked(MockERC20.transfer.selector, abi.encode(address(0x2), uint256(123))); // mock erc20 transfer

        (address[] memory addrList, uint256[] memory valueList) = ksa.extractAddressesWithValue(mockToken, data);

        assertEq(addrList.length, 2);
        assertEq(valueList.length, 2);
        assertEq(address(0x2), address(addrList[0]));
        assertEq(mockToken, address(addrList[1]));
        assertEq(0, valueList[0]);
        assertEq(123, valueList[1]);
    }

    function test_approve_permit2() public {
        // 0x095ea7b3000000000000000000000000000000000022d473030f116ddee9f6b43ac78ba3ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
        bytes memory data =
            hex"095ea7b3000000000000000000000000000000000022d473030f116ddee9f6b43ac78ba3ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff";
        (address[] memory addrList, uint256[] memory valueList) = ksa.extractAddressesWithValue(mockToken, data);

        console.log(addrList.length);
        for (uint256 i = 0; i < addrList.length; i++) {
            console.log("addrList[", i, "]: ", addrList[i]);
            console.log("valueList[", i, "]: ", valueList[i]);
        }
    }
}

// $ yarn test --match-contract ERC20AnalyserTest
