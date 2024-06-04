// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

library Transaction {
    // using Transaction for Props;
    enum Status {
        Pending,
        Cancelled,
        Completed,
        Rejected
    }

    struct Request {
        address requester;
        uint256 policyId;
        Params params;
        Status status;
    }
    
    struct Params {
        address to;
        uint256 value;
        bytes data;
    }
}