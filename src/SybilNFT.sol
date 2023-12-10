// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import {LinkTokenInterface} from "chainlink/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {IRouterClient} from "ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "ccip/src/v0.8/ccip/libraries/Client.sol";

/**
 * @title SybilNFT
 * @author Abhik Banerjee
 * @notice The contract is used to mint Anon AADHAR PCD backed NFTs on Sepolia.
 * If needed, the user can port over their NFT to any network (using Chailink CCIP).
 * The network to which it is being ported over needs to
 * have SybilNFTResolver Contract deployed. For PoC, I demo between Sepolia,
 * Base Goerli and Polygon Mumbai.
 */

contract SybilNFTMain is
    ERC721,
    ERC721Enumerable,
    ERC721URIStorage,
    ERC721Burnable,
    Ownable
{
    uint256 private _nextTokenId;
    mapping(address => bool) public addressMinted;
    enum PayFeesIn {
        Native,
        LINK
    }

    address public s_routerAddress;
    address public s_linkTokenAddress;

    IRouterClient private s_router;
    LinkTokenInterface private s_linkToken;
    error NotEnoughBalance(uint256 currentBalance, uint256 calculatedFees);
    event CloneReqSent(bytes32 messageId, uint tokenId, address owner);

    modifier onlyVerified(bytes memory sig) {
        require(verifiedSig(sig) == true, "User not Authorized");
        _;
    }

    constructor(
        address initialOwner,
        address router,
        address link
    ) ERC721("SybilNFTResolver", "SNT") Ownable(initialOwner) {
        s_routerAddress = router;
        s_linkTokenAddress = link;
    }

    function safeMint(
        address to,
        string memory uri,
        bytes memory signature
    ) public onlyVerified(signature) {
        require(!addressMinted[to], "Already Minted");
        uint256 tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
        addressMinted[to] = true;
    }

    function cloneId(
        uint64 destinationChainSelector,
        address receiver,
        PayFeesIn payFeesIn,
        uint tokenId
    ) external {
        require(_ownerOf(tokenId) == msg.sender, "not token owner");
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(receiver),
            data: abi.encodeWithSignature(
                "mintClone(address,uint)",
                msg.sender, tokenId
            ),
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: "",
            feeToken: payFeesIn == PayFeesIn.LINK
                ? s_linkTokenAddress
                : address(0)
        });
        IRouterClient router = IRouterClient(s_routerAddress);
        // Get the fee required to send the message
        uint256 fees = router.getFee(destinationChainSelector, message);

        bytes32 messageId;

        if (payFeesIn == PayFeesIn.LINK) {
            LinkTokenInterface token = LinkTokenInterface(s_linkTokenAddress);
            if (fees > token.balanceOf(address(this)))
                revert NotEnoughBalance(token.balanceOf(address(this)), fees);

            // approve the Router to transfer LINK tokens on contract's behalf. It will spend the fees in LINK
            token.approve(address(router), fees);

            // LinkTokenInterface(i_link).approve(i_router, fee);
            messageId = router.ccipSend(destinationChainSelector, message);
        } else {
            messageId = router.ccipSend{value: fees}(
                destinationChainSelector,
                message
            );
        }

        emit CloneReqSent(messageId, tokenId, msg.sender);
    }

    // The following functions are overrides required by Solidity.

    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal override(ERC721, ERC721Enumerable) returns (address) {
        return super._update(to, tokenId, auth);
    }

    function verifiedSig(bytes memory signature) internal view returns (bool) {
        bytes32 message = MessageHashUtils.toEthSignedMessageHash(keccak256(abi.encodePacked(_msgSender())));
        return
            SignatureChecker.isValidSignatureNow(owner(), message, signature);
    }

    function _increaseBalance(
        address account,
        uint128 value
    ) internal override(ERC721, ERC721Enumerable) {
        super._increaseBalance(account, value);
    }

    function tokenURI(
        uint256 tokenId
    ) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        override(ERC721, ERC721Enumerable, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
