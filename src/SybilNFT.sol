// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
/**
 * @title SybilNFT
 * @author Abhik Banerjee
 * @notice The contract is used to mint Anon AADHAR PCD backed NFTs on Sepolia.
 * If needed, the user can port over their NFT to any network (using Chailink CCIP).
 * The network to which it is being ported over needs to 
 * have SybilNFTResolver Contract deployed. For PoC, I demo between Sepolia,
 * Base Goerli and Polygon Mumbai. 
 */

contract SybilNFT is ERC721, ERC721Enumerable, ERC721URIStorage, ERC721Burnable, Ownable {
    uint256 private _nextTokenId;
    modifier onlyVerified(bytes memory sig) {
      require(verifiedSig(sig) == true, "User not Authorized");
      _;
    }
    constructor(address initialOwner)
        ERC721("SybilNFTResolver", "SNT")
        Ownable(initialOwner)
    {}

    function safeMint(address to, string memory uri, bytes memory signature) public onlyVerified(signature) {
        uint256 tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
    }

    // The following functions are overrides required by Solidity.

    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721, ERC721Enumerable)
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }

    function verifiedSig(bytes memory signature) internal view returns(bool){
        bytes32 messageHash = keccak256(abi.encodePacked(_msgSender()));
        bytes32 message = MessageHashUtils.toEthSignedMessageHash(messageHash);
        return SignatureChecker.isValidSignatureNow(owner(), message, signature);
    }

    function _increaseBalance(address account, uint128 value)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._increaseBalance(account, value);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}