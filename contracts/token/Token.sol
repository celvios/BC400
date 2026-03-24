// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { ERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import { SafeERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {
    ILayerZeroEndpointV2,
    MessagingParams,
    MessagingFee,
    MessagingReceipt,
    Origin
} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";

import { IOFT, SendParam, OFTLimit, OFTReceipt, OFTFeeDetail } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";
import { OFTMsgCodec } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTMsgCodec.sol";
import { OFTComposeMsgCodec } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTComposeMsgCodec.sol";
import { EnforcedOptionParam } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/interfaces/IOAppOptionsType3.sol";
import { IOAppMsgInspector } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/interfaces/IOAppMsgInspector.sol";

import { TokenStorage } from "./TokenStorage.sol";

/**
 * @title Token
 * @notice Multi-chain ERC-20 token with configurable tax, LayerZero V2 OFT bridging, and UUPS upgradeability.
 *
 * @dev Architecture:
 *  - Upgradeable via UUPS proxy pattern (OpenZeppelin 5.x)
 *  - Cross-chain via LayerZero V2 OFT (burn-on-send, mint-on-receive)
 *  - Tax only applies on regular transfers, NOT on bridge/mint/burn operations
 *  - Tax-exempt: LZ endpoint, migration contract, LP addresses, admin wallets
 *  - Role-based access control (ADMIN, UPGRADER, PAUSER, TAX_MANAGER)
 *
 * @dev The LZ endpoint is set as immutable in the implementation contract.
 *      This is safe with UUPS because immutables live in bytecode, not storage.
 *
 * @dev Storage Layout: see TokenStorage.sol — NEVER reorder existing variables.
 */
contract Token is
    ERC20Upgradeable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuard,
    TokenStorage,
    IOFT
{
    using SafeERC20 for IERC20;
    using OFTMsgCodec for bytes;
    using OFTMsgCodec for bytes32;

    // ============================================================
    //                        CONSTANTS
    // ============================================================

    /// @notice Role for overall admin operations (setting exemptions, managing peers)
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /// @notice Role for upgrading the contract implementation
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    /// @notice Role for pausing/unpausing the contract
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /// @notice Role for managing tax configuration
    bytes32 public constant TAX_MANAGER_ROLE = keccak256("TAX_MANAGER_ROLE");

    /// @notice OFT msg types for LayerZero
    uint16 public constant SEND = 1;
    uint16 public constant SEND_AND_CALL = 2;

    /// @notice LayerZero Options Type 3 identifier
    uint16 internal constant OPTION_TYPE_3 = 3;

    /// @notice OAppSender version
    uint64 internal constant SENDER_VERSION = 1;

    /// @notice OAppReceiver version
    uint64 internal constant RECEIVER_VERSION = 2;

    // ============================================================
    //                     IMMUTABLES (in bytecode)
    // ============================================================

    /// @notice The LayerZero EndpointV2 contract — set once in implementation constructor
    ILayerZeroEndpointV2 public immutable lzEndpoint;

    /// @notice Conversion rate for OFT shared decimals (6) vs local decimals (18)
    uint256 public immutable decimalConversionRate;

    // ============================================================
    //                     STORAGE (in proxy)
    // ============================================================

    /// @notice Mapping of LayerZero endpoint ID => trusted peer address (bytes32 for non-EVM compat)
    mapping(uint32 => bytes32) public peers;

    /// @notice Optional message inspector contract
    address public msgInspector;

    /// @notice Enforced options per (eid, msgType)
    mapping(uint32 => mapping(uint16 => bytes)) public enforcedOptions;

    /// @notice PreCrime simulator contract (optional)
    address public preCrime;

    // ============================================================
    //                         ERRORS
    // ============================================================

    /// @notice Thrown when a zero address is provided where one is not allowed
    error ZeroAddress();

    /// @notice Thrown when the tax BPS exceeds the maximum allowed
    error TaxTooHigh(uint256 provided, uint256 max);

    /// @notice Thrown when only the LZ endpoint should call
    error OnlyEndpoint(address addr);

    /// @notice Thrown when sender is not a trusted peer
    error OnlyPeer(uint32 eid, bytes32 sender);

    /// @notice Thrown when no peer is set for the given EID
    error NoPeer(uint32 eid);

    /// @notice Thrown when delegate address is invalid
    error InvalidDelegate();

    /// @notice Thrown when only self can call
    error OnlySelf();

    /// @notice Thrown when options are invalid
    error InvalidOptions(bytes options);

    /// @notice Thrown when native fee is insufficient
    error NotEnoughNative(uint256 msgValue);

    /// @notice Thrown when LZ token is unavailable
    error LzTokenUnavailable();

    // ============================================================
    //                         EVENTS
    // ============================================================

    /// @notice Emitted when tax is collected during a transfer
    event TaxCollected(address indexed from, address indexed to, uint256 amount);

    /// @notice Emitted when the tax wallet is updated
    event TaxWalletUpdated(address indexed oldWallet, address indexed newWallet);

    /// @notice Emitted when a tax exemption is updated
    event TaxExemptUpdated(address indexed account, bool exempt);

    /// @notice Emitted when tax collection is enabled or disabled
    event TaxEnabledUpdated(bool enabled);

    /// @notice Emitted when the tax rate is updated
    event TaxBpsUpdated(uint256 oldBps, uint256 newBps);

    /// @notice Emitted when a peer is set
    event PeerSet(uint32 eid, bytes32 peer);

    /// @notice Emitted when the message inspector is set
    event MsgInspectorSet(address inspector);

    /// @notice Emitted when the preCrime address is set
    event PreCrimeSet(address preCrime);

    /// @notice Emitted when enforced options are set
    event EnforcedOptionSet(EnforcedOptionParam[] enforcedOptions);

    // ============================================================
    //                      CONSTRUCTOR
    // ============================================================

    /**
     * @notice Sets the LayerZero endpoint (immutable in bytecode).
     * @param _lzEndpoint The LayerZero EndpointV2 address.
     * @dev This constructor runs on the IMPLEMENTATION contract, not the proxy.
     *      The endpoint is stored as an immutable, which lives in bytecode.
     * @custom:oz-upgrades-unsafe-allow constructor
     */
    constructor(address _lzEndpoint) {
        if (_lzEndpoint == address(0)) revert ZeroAddress();
        lzEndpoint = ILayerZeroEndpointV2(_lzEndpoint);

        // 18 local decimals - 6 shared decimals = 12 => 10^12 conversion rate
        uint8 _localDecimals = 18;
        uint8 _sharedDecimals = 6;
        if (_localDecimals < _sharedDecimals) revert InvalidLocalDecimals();
        decimalConversionRate = 10 ** (_localDecimals - _sharedDecimals);

        _disableInitializers();
    }

    // ============================================================
    //                      INITIALIZER
    // ============================================================

    /**
     * @notice Initializes the token proxy with all configuration.
     * @param _admin The initial admin who receives all roles.
     * @param _taxWallet The wallet that receives tax from transfers.
     * @param _name The token name.
     * @param _symbol The token symbol.
     * @param _totalSupply The total supply to mint to the admin.
     * @param _initialTaxBps The initial tax rate in basis points (e.g., 200 = 2%).
     */
    function initialize(
        address _admin,
        address _taxWallet,
        string memory _name,
        string memory _symbol,
        uint256 _totalSupply,
        uint256 _initialTaxBps
    ) external initializer {
        if (_admin == address(0)) revert ZeroAddress();
        if (_taxWallet == address(0)) revert ZeroAddress();
        if (_initialTaxBps > MAX_TAX_BPS) revert TaxTooHigh(_initialTaxBps, MAX_TAX_BPS);

        __ERC20_init(_name, _symbol);
        __AccessControl_init();
        __Pausable_init();

        // Set up roles — admin gets all roles initially
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(ADMIN_ROLE, _admin);
        _grantRole(UPGRADER_ROLE, _admin);
        _grantRole(PAUSER_ROLE, _admin);
        _grantRole(TAX_MANAGER_ROLE, _admin);

        // Set tax configuration
        taxWallet = _taxWallet;
        taxEnabled = true;
        taxBps = _initialTaxBps;

        // Exempt admin and tax wallet from tax
        taxExempt[_admin] = true;
        taxExempt[_taxWallet] = true;

        // Set delegate on the LZ endpoint
        lzEndpoint.setDelegate(_admin);

        // Mint total supply to admin
        _mint(_admin, _totalSupply);
    }

    // ============================================================
    //                  ERC-20 TRANSFER + TAX
    // ============================================================

    /**
     * @notice Override of ERC-20 _update to inject tax logic.
     * @dev Tax is applied on all transfers where:
     *      - taxEnabled == true
     *      - Neither sender nor recipient is taxExempt
     *      - Neither from nor to is address(0) (mints/burns are never taxed)
     * @param from The sender address.
     * @param to The recipient address.
     * @param amount The transfer amount.
     */
    function _update(address from, address to, uint256 amount) internal virtual override {
        _requireNotPaused();

        // Mints (from == 0) and burns (to == 0) are never taxed
        if (from != address(0) && to != address(0) && taxEnabled && !taxExempt[from] && !taxExempt[to]) {
            uint256 taxAmount = (amount * taxBps) / BPS_DENOMINATOR;
            if (taxAmount > 0) {
                // Checks-Effects-Interactions: update state before external calls
                unchecked {
                    totalTaxCollected += taxAmount;
                }

                uint256 remainder;
                unchecked {
                    remainder = amount - taxAmount;
                }

                // Transfer tax to taxWallet, then remainder to recipient
                super._update(from, taxWallet, taxAmount);
                super._update(from, to, remainder);

                emit TaxCollected(from, to, taxAmount);
                return;
            }
        }

        // No tax path
        super._update(from, to, amount);
    }

    // ============================================================
    //                  TAX MANAGEMENT
    // ============================================================

    /**
     * @notice Set the wallet that receives tax.
     * @param wallet The new tax wallet address.
     */
    function setTaxWallet(address wallet) external onlyRole(TAX_MANAGER_ROLE) {
        if (wallet == address(0)) revert ZeroAddress();
        address old = taxWallet;
        taxWallet = wallet;
        emit TaxWalletUpdated(old, wallet);
    }

    /**
     * @notice Enable or disable tax collection.
     * @param enabled Whether to enable tax.
     */
    function setTaxEnabled(bool enabled) external onlyRole(TAX_MANAGER_ROLE) {
        taxEnabled = enabled;
        emit TaxEnabledUpdated(enabled);
    }

    /**
     * @notice Set tax exemption for an account.
     * @param account The account to update.
     * @param exempt Whether the account should be exempt.
     */
    function setTaxExempt(address account, bool exempt) external onlyRole(ADMIN_ROLE) {
        if (account == address(0)) revert ZeroAddress();
        taxExempt[account] = exempt;
        emit TaxExemptUpdated(account, exempt);
    }

    /**
     * @notice Set the tax rate in basis points.
     * @param bps The new tax rate (must not exceed MAX_TAX_BPS).
     */
    function setTaxBps(uint256 bps) external onlyRole(TAX_MANAGER_ROLE) {
        if (bps > MAX_TAX_BPS) revert TaxTooHigh(bps, MAX_TAX_BPS);
        uint256 old = taxBps;
        taxBps = bps;
        emit TaxBpsUpdated(old, bps);
    }

    // ============================================================
    //                  PAUSE
    // ============================================================

    /// @notice Pause all token transfers.
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /// @notice Unpause token transfers.
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    // ============================================================
    //                  UUPS UPGRADE
    // ============================================================

    /**
     * @notice Authorizes an upgrade to a new implementation.
     * @param newImplementation The new implementation address.
     * @dev Only callable by addresses with the UPGRADER_ROLE.
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) { }

    // ============================================================
    //                LAYERZERO V2 OFT — VIEWS
    // ============================================================

    /// @inheritdoc IOFT
    function oftVersion() external pure returns (bytes4 interfaceId, uint64 version) {
        return (type(IOFT).interfaceId, 1);
    }

    /// @notice Returns the OApp version info.
    function oAppVersion() external pure returns (uint64 senderVersion, uint64 receiverVersion) {
        return (SENDER_VERSION, RECEIVER_VERSION);
    }

    /// @inheritdoc IOFT
    function token() external view returns (address) {
        return address(this);
    }

    /// @inheritdoc IOFT
    function approvalRequired() external pure returns (bool) {
        return false;
    }

    /// @inheritdoc IOFT
    function sharedDecimals() public pure returns (uint8) {
        return 6;
    }

    /// @notice Returns the LayerZero endpoint address.
    function endpoint() external view returns (ILayerZeroEndpointV2) {
        return lzEndpoint;
    }

    // ============================================================
    //                LAYERZERO V2 OFT — SEND
    // ============================================================

    /// @inheritdoc IOFT
    function quoteOFT(SendParam calldata _sendParam)
        external
        view
        returns (OFTLimit memory oftLimit, OFTFeeDetail[] memory oftFeeDetails, OFTReceipt memory oftReceipt)
    {
        uint256 minAmountLD = 0;
        uint256 maxAmountLD = type(uint64).max;
        oftLimit = OFTLimit(minAmountLD, maxAmountLD);
        oftFeeDetails = new OFTFeeDetail[](0);

        (uint256 amountSentLD, uint256 amountReceivedLD) =
            _debitView(_sendParam.amountLD, _sendParam.minAmountLD, _sendParam.dstEid);
        oftReceipt = OFTReceipt(amountSentLD, amountReceivedLD);
    }

    /// @inheritdoc IOFT
    function quoteSend(SendParam calldata _sendParam, bool _payInLzToken)
        external
        view
        returns (MessagingFee memory msgFee)
    {
        (, uint256 amountReceivedLD) = _debitView(_sendParam.amountLD, _sendParam.minAmountLD, _sendParam.dstEid);
        (bytes memory message, bytes memory options) = _buildMsgAndOptions(_sendParam, amountReceivedLD);
        return _quote(_sendParam.dstEid, message, options, _payInLzToken);
    }

    /// @inheritdoc IOFT
    function send(SendParam calldata _sendParam, MessagingFee calldata _fee, address _refundAddress)
        external
        payable
        nonReentrant
        returns (MessagingReceipt memory msgReceipt, OFTReceipt memory oftReceipt)
    {
        _requireNotPaused();

        (uint256 amountSentLD, uint256 amountReceivedLD) =
            _debit(msg.sender, _sendParam.amountLD, _sendParam.minAmountLD, _sendParam.dstEid);

        (bytes memory message, bytes memory options) = _buildMsgAndOptions(_sendParam, amountReceivedLD);

        msgReceipt = _lzSend(_sendParam.dstEid, message, options, _fee, _refundAddress);
        oftReceipt = OFTReceipt(amountSentLD, amountReceivedLD);

        emit OFTSent(msgReceipt.guid, _sendParam.dstEid, msg.sender, amountSentLD, amountReceivedLD);
    }

    // ============================================================
    //              LAYERZERO V2 OFT — RECEIVE
    // ============================================================

    /**
     * @notice Entry point for receiving messages from the LayerZero endpoint.
     * @param _origin The origin information (srcEid, sender, nonce).
     * @param _guid The unique identifier for the received message.
     * @param _message The encoded message payload.
     * @param _executor The executor address.
     * @param _extraData Additional data.
     */
    function lzReceive(
        Origin calldata _origin,
        bytes32 _guid,
        bytes calldata _message,
        address _executor,
        bytes calldata _extraData
    ) external payable {
        if (address(lzEndpoint) != msg.sender) revert OnlyEndpoint(msg.sender);
        if (_getPeerOrRevert(_origin.srcEid) != _origin.sender) revert OnlyPeer(_origin.srcEid, _origin.sender);
        _lzReceive(_origin, _guid, _message, _executor, _extraData);
    }

    /**
     * @notice Checks if the path initialization is allowed.
     * @param origin The origin information.
     * @return Whether the path has been initialized (peer is set).
     */
    function allowInitializePath(Origin calldata origin) external view returns (bool) {
        return peers[origin.srcEid] == origin.sender;
    }

    /// @notice Returns the next nonce (0 = no ordering enforcement).
    function nextNonce(uint32, bytes32) external pure returns (uint64) {
        return 0;
    }

    // ============================================================
    //              LAYERZERO V2 — PEER MANAGEMENT
    // ============================================================

    /**
     * @notice Sets the peer address for a corresponding endpoint.
     * @param _eid The endpoint ID.
     * @param _peer The address of the peer (bytes32 for non-EVM compat).
     */
    function setPeer(uint32 _eid, bytes32 _peer) external onlyRole(ADMIN_ROLE) {
        peers[_eid] = _peer;
        emit PeerSet(_eid, _peer);
    }

    /**
     * @notice Sets the delegate address for the LZ endpoint.
     * @param _delegate The delegate address.
     */
    function setDelegate(address _delegate) external onlyRole(ADMIN_ROLE) {
        if (_delegate == address(0)) revert InvalidDelegate();
        lzEndpoint.setDelegate(_delegate);
    }

    /**
     * @notice Sets the message inspector address.
     * @param _msgInspector The inspector address (address(0) to disable).
     */
    function setMsgInspector(address _msgInspector) external onlyRole(ADMIN_ROLE) {
        msgInspector = _msgInspector;
        emit MsgInspectorSet(_msgInspector);
    }

    /**
     * @notice Sets the preCrime contract address.
     * @param _preCrime The preCrime address.
     */
    function setPreCrime(address _preCrime) external onlyRole(ADMIN_ROLE) {
        preCrime = _preCrime;
        emit PreCrimeSet(_preCrime);
    }

    /**
     * @notice Sets enforced options for specific (eid, msgType) combinations.
     * @param _enforcedOptions Array of enforced option parameters.
     */
    function setEnforcedOptions(EnforcedOptionParam[] calldata _enforcedOptions) external onlyRole(ADMIN_ROLE) {
        for (uint256 i = 0; i < _enforcedOptions.length; i++) {
            _assertOptionsType3(_enforcedOptions[i].options);
            enforcedOptions[_enforcedOptions[i].eid][_enforcedOptions[i].msgType] = _enforcedOptions[i].options;
        }
        emit EnforcedOptionSet(_enforcedOptions);
    }

    /**
     * @notice Checks if the specified peer is trusted.
     * @param _eid The endpoint ID.
     * @param _peer The peer to check.
     * @return Whether the peer is trusted.
     */
    function isPeer(uint32 _eid, bytes32 _peer) public view returns (bool) {
        return peers[_eid] == _peer;
    }

    // ============================================================
    //              INTERNAL — OFT DEBIT / CREDIT
    // ============================================================

    /**
     * @dev Burns tokens from the sender for cross-chain send (debit).
     * @dev Bridge transactions are ALWAYS tax-exempt — taxing bridge tx breaks OFT mechanics.
     */
    function _debit(address _from, uint256 _amountLD, uint256 _minAmountLD, uint32 _dstEid)
        internal
        returns (uint256 amountSentLD, uint256 amountReceivedLD)
    {
        (amountSentLD, amountReceivedLD) = _debitView(_amountLD, _minAmountLD, _dstEid);
        _burn(_from, amountSentLD);
    }

    /**
     * @dev Mints tokens to the recipient for cross-chain receive (credit).
     * @dev Bridge transactions are ALWAYS tax-exempt.
     */
    function _credit(address _to, uint256 _amountLD, uint32) internal returns (uint256 amountReceivedLD) {
        if (_to == address(0x0)) _to = address(0xdead);
        _mint(_to, _amountLD);
        return _amountLD;
    }

    /**
     * @dev View function to calculate debit amounts (removes dust for decimal conversion).
     */
    function _debitView(uint256 _amountLD, uint256 _minAmountLD, uint32)
        internal
        view
        returns (uint256 amountSentLD, uint256 amountReceivedLD)
    {
        amountSentLD = _removeDust(_amountLD);
        amountReceivedLD = amountSentLD;
        if (amountReceivedLD < _minAmountLD) {
            revert SlippageExceeded(amountReceivedLD, _minAmountLD);
        }
    }

    // ============================================================
    //              INTERNAL — OFT MESSAGE BUILDING
    // ============================================================

    function _lzReceive(Origin calldata _origin, bytes32 _guid, bytes calldata _message, address, bytes calldata)
        internal
    {
        address toAddress = _message.sendTo().bytes32ToAddress();
        uint256 amountReceivedLD = _credit(toAddress, _toLD(_message.amountSD()), _origin.srcEid);

        if (_message.isComposed()) {
            bytes memory composeMsg = OFTComposeMsgCodec.encode(
                _origin.nonce, _origin.srcEid, amountReceivedLD, _message.composeMsg()
            );
            lzEndpoint.sendCompose(toAddress, _guid, 0, composeMsg);
        }

        emit OFTReceived(_guid, _origin.srcEid, toAddress, amountReceivedLD);
    }

    function _buildMsgAndOptions(SendParam calldata _sendParam, uint256 _amountLD)
        internal
        view
        returns (bytes memory message, bytes memory options)
    {
        bool hasCompose;
        (message, hasCompose) = OFTMsgCodec.encode(_sendParam.to, _toSD(_amountLD), _sendParam.composeMsg);
        uint16 msgType = hasCompose ? SEND_AND_CALL : SEND;
        options = combineOptions(_sendParam.dstEid, msgType, _sendParam.extraOptions);

        if (msgInspector != address(0)) {
            IOAppMsgInspector(msgInspector).inspect(message, options);
        }
    }

    // ============================================================
    //              INTERNAL — LAYERZERO SEND / QUOTE
    // ============================================================

    function _lzSend(
        uint32 _dstEid,
        bytes memory _message,
        bytes memory _options,
        MessagingFee memory _fee,
        address _refundAddress
    ) internal returns (MessagingReceipt memory receipt) {
        uint256 messageValue = _payNative(_fee.nativeFee);
        if (_fee.lzTokenFee > 0) _payLzToken(_fee.lzTokenFee);

        return lzEndpoint.send{ value: messageValue }(
            MessagingParams(_dstEid, _getPeerOrRevert(_dstEid), _message, _options, _fee.lzTokenFee > 0), _refundAddress
        );
    }

    function _quote(uint32 _dstEid, bytes memory _message, bytes memory _options, bool _payInLzToken)
        internal
        view
        returns (MessagingFee memory fee)
    {
        return lzEndpoint.quote(
            MessagingParams(_dstEid, _getPeerOrRevert(_dstEid), _message, _options, _payInLzToken), address(this)
        );
    }

    function _payNative(uint256 _nativeFee) internal returns (uint256) {
        if (msg.value < _nativeFee) revert NotEnoughNative(msg.value);
        return _nativeFee;
    }

    function _payLzToken(uint256 _lzTokenFee) internal {
        address lzToken = lzEndpoint.lzToken();
        if (lzToken == address(0)) revert LzTokenUnavailable();
        IERC20(lzToken).safeTransferFrom(msg.sender, address(lzEndpoint), _lzTokenFee);
    }

    // ============================================================
    //              INTERNAL — OFT DECIMAL HELPERS
    // ============================================================

    function _removeDust(uint256 _amountLD) internal view returns (uint256) {
        return (_amountLD / decimalConversionRate) * decimalConversionRate;
    }

    function _toLD(uint64 _amountSD) internal view returns (uint256) {
        return _amountSD * decimalConversionRate;
    }

    function _toSD(uint256 _amountLD) internal view returns (uint64) {
        return uint64(_amountLD / decimalConversionRate);
    }

    // ============================================================
    //              OPTIONS COMBINING (public view)
    // ============================================================

    /**
     * @notice Combines caller-provided options with enforced options.
     * @param _eid The endpoint ID.
     * @param _msgType The message type (SEND or SEND_AND_CALL).
     * @param _extraOptions Additional caller-provided options.
     * @return Combined options bytes.
     */
    function combineOptions(uint32 _eid, uint16 _msgType, bytes calldata _extraOptions)
        public
        view
        returns (bytes memory)
    {
        bytes memory enforced = enforcedOptions[_eid][_msgType];

        if (enforced.length == 0) return _extraOptions;
        if (_extraOptions.length == 0) return enforced;

        if (_extraOptions.length >= 2) {
            _assertOptionsType3(_extraOptions);
            return bytes.concat(enforced, _extraOptions[2:]);
        }

        revert InvalidOptions(_extraOptions);
    }

    function _assertOptionsType3(bytes memory _options) internal pure {
        uint16 optionsType;
        assembly {
            optionsType := mload(add(_options, 2))
        }
        if (optionsType != OPTION_TYPE_3) revert InvalidOptions(_options);
    }

    // ============================================================
    //              INTERNAL — PEER HELPERS
    // ============================================================

    function _getPeerOrRevert(uint32 _eid) internal view returns (bytes32) {
        bytes32 peer = peers[_eid];
        if (peer == bytes32(0)) revert NoPeer(_eid);
        return peer;
    }
}
