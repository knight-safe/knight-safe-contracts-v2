// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

library SettingUtils {
    enum Status {
        Pending,
        Cancelled,
        Completed,
        Rejected
    }

    struct Request {
        address requester;
        uint8 selector;
        bytes data;
        Status status;
    }
}

library SettingSelectors {
    bytes4 internal constant CREATE_POLICY = 0xa91a0ca3;
    bytes4 internal constant UPDATE_WHITELIST = 0x725d42f5;
    bytes4 internal constant ADD_TRADER = 0xedbdf62b;
    bytes4 internal constant REMOVE_POLICY = 0x6caddcdc;
    bytes4 internal constant REMOVE_TRADER = 0x29953ff5;
    bytes4 internal constant REMOVE_WHITELIST = 0x94008a6e;
    bytes4 internal constant INCREASE_SPENDING_LIMIT = 0xcc19223b;
    bytes4 internal constant RESET_SPENDING_LIMIT = 0x86e43e16;
}
