// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.12;

/* solhint-disable avoid-low-level-calls */
/* solhint-disable no-inline-assembly */
/* solhint-disable reason-string */

import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

import "account-abstraction/core/BaseAccount.sol";
import "account-abstraction/samples/callback/TokenCallbackHandler.sol";

/**
 *  minimal account.
 *  this is sample minimal account.
 *  has execute, eth handling methods
 *  has a single signer that can send requests through the entryPoint.
 */
contract GGWAccount is
    BaseAccount,
    TokenCallbackHandler,
    UUPSUpgradeable,
    Initializable
{
    using MessageHashUtils for bytes32;

    address public owner;
    mapping(address => uint8) inheritorShareMapping;
    mapping(address => bool) inheritorAddressMapping;
    address[] inheritorsArr;

    uint8 inheritors;
    uint8 shareAgg;

    bool redemptionPeriodStarted;
    uint redemptionPeriodStartBlock;
    address redemptionStarter;

    IEntryPoint private immutable _entryPoint;

    event SimpleAccountInitialized(
        IEntryPoint indexed entryPoint,
        address indexed owner
    );

    modifier onlyOwner() {
        _onlyOwner();
        _;
    }

    /// @inheritdoc BaseAccount
    function entryPoint() public view virtual override returns (IEntryPoint) {
        return _entryPoint;
    }

    // solhint-disable-next-line no-empty-blocks
    receive() external payable {}

    constructor(IEntryPoint anEntryPoint) {
        _entryPoint = anEntryPoint;
        _disableInitializers();
    }

    function _onlyOwner() internal view {
        //directly from EOA owner, or through the account itself (which gets redirected through execute())
        require(
            msg.sender == owner || msg.sender == address(this),
            "only owner"
        );
    }

    /**
     * execute a transaction (called directly from owner, or by entryPoint)
     */
    function execute(
        address dest,
        uint256 value,
        bytes calldata func
    ) external {
        _requireFromEntryPointOrOwner();
        _call(dest, value, func);
    }

    /**
     * execute a sequence of transactions
     */
    function executeBatch(
        address[] calldata dest,
        bytes[] calldata func
    ) external {
        _requireFromEntryPointOrOwner();
        require(dest.length == func.length, "wrong array lengths");
        for (uint256 i = 0; i < dest.length; i++) {
            _call(dest[i], 0, func[i]);
        }
    }

    /**
     * @dev The _entryPoint member is immutable, to reduce gas consumption.  To upgrade EntryPoint,
     * a new implementation of SimpleAccount must be deployed with the new EntryPoint address, then upgrading
     * the implementation by calling `upgradeTo()`
     */
    function initialize(address anOwner) public virtual initializer {
        _initialize(anOwner);
    }

    function _initialize(address anOwner) internal virtual {
        owner = anOwner;
        emit SimpleAccountInitialized(_entryPoint, owner);
    }

    // Require the function call went through EntryPoint or owner
    function _requireFromEntryPointOrOwner() internal view {
        require(
            msg.sender == address(entryPoint()) || msg.sender == owner,
            "account: not Owner or EntryPoint"
        );
    }

    // Require the function call went through EntryPoint or owner or inheritors
    function _requireFromEntryPointOrOwnerOrInheritor() internal view {
        require(
            msg.sender == address(entryPoint()) ||
                msg.sender == owner ||
                inheritorAddressMapping[msg.sender],
            "account: not owner, inheritor or EntryPoint"
        );
    }

    /// implement template method of BaseAccount
    function _validateSignature(
        UserOperation calldata userOp,
        bytes32 userOpHash
    ) internal virtual override returns (uint256 validationData) {
        bytes32 hash = userOpHash.toEthSignedMessageHash();

        if (
            !SignatureChecker.isValidSignatureNow(owner, hash, userOp.signature)
        ) {
            uint8 inheritorsArrLength = uint8(inheritorsArr.length);
            for (uint8 i = 0; i < inheritorsArrLength; i++) {
                if (
                    SignatureChecker.isValidSignatureNow(
                        inheritorsArr[i],
                        hash,
                        userOp.signature
                    )
                ) {
                    return 0;
                }
            }
            return SIG_VALIDATION_FAILED;
        }

        return 0;
    }

    function _call(address target, uint256 value, bytes memory data) internal {
        (bool success, bytes memory result) = target.call{value: value}(data);
        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }

    /**
     * check current account deposit in the entryPoint
     */
    function getDeposit() public view returns (uint256) {
        return entryPoint().balanceOf(address(this));
    }

    /**
     * deposit more funds for this account in the entryPoint
     */
    function addDeposit() public payable {
        entryPoint().depositTo{value: msg.value}(address(this));
    }

    /**
     * withdraw value from the account's deposit
     * @param withdrawAddress target to send to
     * @param amount to withdraw
     */
    function withdrawDepositTo(
        address payable withdrawAddress,
        uint256 amount
    ) public onlyOwner {
        entryPoint().withdrawTo(withdrawAddress, amount);
    }

    function appendInheritor(
        address inheritor,
        uint8 share
    ) external onlyOwner {
        bool newInheritor = !inheritorAddressMapping[inheritor];
        require(newInheritor && share + shareAgg <= 100, "Shares Exceed 100%");
        if (!newInheritor) {
            uint8 oldShare = inheritorShareMapping[inheritor];
            require((shareAgg - oldShare) + share <= 100, "Shares Exceed 100%");
        }
        if (newInheritor) {
            require(
                inheritors + 1 < type(uint8).max,
                "Max no. inheritors reached"
            );
            inheritorAddressMapping[inheritor] = true;
            inheritorsArr.push();
            ++inheritors;
        }
        inheritorShareMapping[inheritor] = share;
    }

    function removeInheritor(address inheritor) external onlyOwner {
        require(inheritorAddressMapping[inheritor], "Inheritor nonexistent");
        inheritorAddressMapping[inheritor] = false;
        uint8 share = inheritorShareMapping[inheritor];
        shareAgg = shareAgg - share;
        inheritorShareMapping[inheritor] = 0;
        uint8 inheritorsArrLength = uint8(inheritorsArr.length);
        uint8 i = 0;
        for (; i < inheritorsArrLength; i++) {
            if (inheritorsArr[i] == inheritor) break;
        }
        inheritorsArr[i] = inheritorsArr[inheritorsArrLength - 1];
        inheritorsArr.pop();
    }

    function startRedemption() external {
        _requireFromEntryPointOrOwnerOrInheritor();
        redemptionPeriodStarted = true;
        redemptionPeriodStartBlock = block.number;
        redemptionStarter = msg.sender;
    }

    function stopRedemption() external {
        _requireFromEntryPointOrOwner();
        redemptionPeriodStarted = true;
    }

    function redeem(address payable inheritor) external {
        require(inheritorAddressMapping[inheritor], "not inheritor");
        _requireFromEntryPointOrOwnerOrInheritor();
        require(
            redemptionPeriodStarted && block.number == redemptionPeriodStartBlock + 1,
            "Period not elasped"
        );
        uint8 share = inheritorShareMapping[inheritor];
        uint inheritorShare = (share *
            entryPoint().getDepositInfo(address(this)).deposit) / 100;
        entryPoint().withdrawTo(payable(inheritor), inheritorShare);
        inheritorAddressMapping[inheritor] = false;
        inheritorShareMapping[inheritor] = 0;
        shareAgg = shareAgg - share;
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal view override {
        (newImplementation);
        _onlyOwner();
    }
}
