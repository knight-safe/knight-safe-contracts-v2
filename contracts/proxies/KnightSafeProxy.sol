// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Proxy} from "@openzeppelin/contracts/proxy/Proxy.sol";
import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import {ControlCenterManager} from "../base/ControlCenterManager.sol";
import {IControlCenter} from "../interfaces/IControlCenter.sol";
import {IOwnerManager} from "../interfaces/IOwnerManager.sol";
import "@/error/Errors.sol";

contract KnightSafeProxy is Proxy {
    constructor(address implementation) {
        if (implementation == address(0)) revert Errors.IsNullValue();
        bytes memory _data;
        ERC1967Utils.upgradeToAndCall(implementation, _data);
    }

    function _implementation() internal view virtual override returns (address) {
        return ERC1967Utils.getImplementation();
    }

    function upgradeTo(address implementation) public returns (address) {
        if (implementation == address(0)) revert Errors.IsNullValue();

        if (IOwnerManager(address(this)).getOwner() != msg.sender) {
            revert Errors.Unauthorized(msg.sender, "OWNER");
        }

        address controlCenter = ControlCenterManager(address(this)).getControlCenter();
        if (!IControlCenter(controlCenter).isOfficialImplementation(implementation)) {
            revert Errors.AddressIsNotKnightSafeImplementation(implementation);
        }

        bytes memory _data;
        ERC1967Utils.upgradeToAndCall(implementation, _data);
    }
}
