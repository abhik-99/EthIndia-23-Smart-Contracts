// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import {Client} from "ccip/src/v0.8/ccip/libraries/Client.sol";
import {CCIPReceiver} from "ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";

contract SybilNFTResolver is ERC721, Ownable, CCIPReceiver {
    event ClonnedToken(bytes32 messageId);

    constructor(
        address initialOwner
    ) ERC721("SybilNFT", "SNR") Ownable(initialOwner) {}

    function _ccipReceive(
        Client.Any2EVMMessage memory message
    ) internal override {
        (bool success, ) = address(this).call(message.data);
        require(success);
        emit ClonnedToken(message.messageId);
    }
}
