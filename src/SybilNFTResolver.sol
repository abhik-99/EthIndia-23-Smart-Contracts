// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SybilNFTResolver is ERC721, Ownable {
    constructor(address initialOwner)
        ERC721("SybilNFT", "SNR")
        Ownable(initialOwner)
    {}

}