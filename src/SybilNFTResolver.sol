// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

import {Client} from "ccip/src/v0.8/ccip/libraries/Client.sol";
import {CCIPReceiver} from "ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";

contract SybilNFTResolver is Ownable, CCIPReceiver {
    address public cloneContractAddress;
    event ClonnedToken(bytes32 messageId);

    constructor(
        address initialOwner,
        address router,
        address cloneAddr
    ) CCIPReceiver(router) Ownable(initialOwner) {
        cloneContractAddress = cloneAddr;
    }

    function _ccipReceive(
        Client.Any2EVMMessage memory message
    ) internal override {
        (bool success, ) = address(cloneContractAddress).call(message.data);
        require(success);
        emit ClonnedToken(message.messageId);
    }
}
