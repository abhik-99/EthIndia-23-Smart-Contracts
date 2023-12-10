// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SybilNFTClone is ERC721, Ownable {
    constructor(
        address initialOwner
    ) ERC721("SybilNFT", "SNR") Ownable(initialOwner) {}

    function mintClone(address to, uint tokenId) external onlyOwner {
        _safeMint(to, tokenId);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
