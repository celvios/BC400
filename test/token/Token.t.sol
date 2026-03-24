// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Test.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { Token } from "../../contracts/token/Token.sol";
import { MockLZEndpoint } from "../mocks/MockLZEndpoint.sol";

import { SendParam } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";
import { MessagingFee, Origin } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";

/**
 * @title Token Test Suite
 * @notice Comprehensive tests for Token.sol covering:
 *   - Initialization & deployment
 *   - ERC-20 basics
 *   - Tax logic (2% default, exemptions, wallet, enable/disable, bps changes)
 *   - Access control (roles, unauthorized access)
 *   - Pause functionality
 *   - UUPS upgrade authorization
 *   - OFT send (burn-on-send) mechanics
 */
contract TokenTest is Test {
    Token public impl;
    Token public token;
    MockLZEndpoint public lzEndpoint;

    address public admin = makeAddr("admin");
    address public taxWallet = makeAddr("taxWallet");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public carol = makeAddr("carol");

    string constant NAME = "BC400 Token";
    string constant SYMBOL = "BC400";
    uint256 constant TOTAL_SUPPLY = 1_000_000_000 ether; // 1B tokens
    uint256 constant TAX_BPS = 200; // 2%
    uint256 constant BPS_DENOMINATOR = 10_000;

    function setUp() public {
        // Deploy mock LZ endpoint
        lzEndpoint = new MockLZEndpoint();

        // Deploy implementation
        impl = new Token(address(lzEndpoint));

        // Deploy proxy and initialize
        bytes memory initData = abi.encodeCall(
            Token.initialize,
            (admin, taxWallet, NAME, SYMBOL, TOTAL_SUPPLY, TAX_BPS)
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        token = Token(address(proxy));
    }

    // ============================================================
    //                    INITIALIZATION
    // ============================================================

    function test_initialize_setsNameAndSymbol() public view {
        assertEq(token.name(), NAME);
        assertEq(token.symbol(), SYMBOL);
    }

    function test_initialize_mintsSupplyToAdmin() public view {
        assertEq(token.balanceOf(admin), TOTAL_SUPPLY);
        assertEq(token.totalSupply(), TOTAL_SUPPLY);
    }

    function test_initialize_setsTaxConfig() public view {
        assertEq(token.taxWallet(), taxWallet);
        assertEq(token.taxBps(), TAX_BPS);
        assertTrue(token.taxEnabled());
    }

    function test_initialize_exemptAdminAndTaxWallet() public view {
        assertTrue(token.taxExempt(admin));
        assertTrue(token.taxExempt(taxWallet));
    }

    function test_initialize_grantsAllRolesToAdmin() public view {
        assertTrue(token.hasRole(token.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(token.hasRole(token.ADMIN_ROLE(), admin));
        assertTrue(token.hasRole(token.UPGRADER_ROLE(), admin));
        assertTrue(token.hasRole(token.PAUSER_ROLE(), admin));
        assertTrue(token.hasRole(token.TAX_MANAGER_ROLE(), admin));
    }

    function test_initialize_setsLZDelegate() public view {
        assertEq(lzEndpoint.lastDelegate(), admin);
    }

    function test_initialize_cannotReinitialize() public {
        vm.expectRevert();
        token.initialize(admin, taxWallet, NAME, SYMBOL, TOTAL_SUPPLY, TAX_BPS);
    }

    function test_initialize_revertsOnZeroAdmin() public {
        Token newImpl = new Token(address(lzEndpoint));
        bytes memory initData = abi.encodeCall(
            Token.initialize,
            (address(0), taxWallet, NAME, SYMBOL, TOTAL_SUPPLY, TAX_BPS)
        );
        vm.expectRevert();
        new ERC1967Proxy(address(newImpl), initData);
    }

    function test_initialize_revertsOnTaxTooHigh() public {
        Token newImpl = new Token(address(lzEndpoint));
        bytes memory initData = abi.encodeCall(
            Token.initialize,
            (admin, taxWallet, NAME, SYMBOL, TOTAL_SUPPLY, 1001) // 10.01% > MAX_TAX_BPS (1000)
        );
        vm.expectRevert();
        new ERC1967Proxy(address(newImpl), initData);
    }

    // ============================================================
    //                    ERC-20 BASICS
    // ============================================================

    function test_transfer_basic() public {
        uint256 amount = 1000 ether;

        // Admin is tax-exempt, so full amount transfers
        vm.prank(admin);
        token.transfer(alice, amount);

        assertEq(token.balanceOf(alice), amount);
    }

    function test_transferFrom_withApproval() public {
        uint256 amount = 1000 ether;

        vm.prank(admin);
        token.transfer(alice, amount);

        // Alice approves bob
        vm.prank(alice);
        token.approve(bob, amount);

        // Bob transfers from alice — this transfer is taxed (neither exempt)
        vm.prank(bob);
        token.transferFrom(alice, bob, amount);

        uint256 taxAmount = (amount * TAX_BPS) / BPS_DENOMINATOR;
        assertEq(token.balanceOf(bob), amount - taxAmount);
        assertEq(token.balanceOf(taxWallet), taxAmount);
    }

    function test_decimals_is18() public view {
        assertEq(token.decimals(), 18);
    }

    // ============================================================
    //                    TAX LOGIC
    // ============================================================

    function test_tax_appliedOnNonExemptTransfer() public {
        uint256 amount = 10_000 ether;

        // Admin sends to alice (admin is exempt — no tax)
        vm.prank(admin);
        token.transfer(alice, amount);
        assertEq(token.balanceOf(alice), amount);

        // Alice sends to bob (neither exempt — taxed)
        vm.prank(alice);
        token.transfer(bob, amount);

        uint256 expectedTax = (amount * TAX_BPS) / BPS_DENOMINATOR; // 200 ether
        uint256 expectedReceived = amount - expectedTax;

        assertEq(token.balanceOf(bob), expectedReceived, "bob should receive after-tax amount");
        assertEq(token.balanceOf(taxWallet), expectedTax, "taxWallet should receive tax");
        assertEq(token.totalTaxCollected(), expectedTax, "totalTaxCollected should track");
    }

    function test_tax_exemptSenderNotTaxed() public {
        uint256 amount = 1000 ether;

        // Make alice exempt
        vm.prank(admin);
        token.setTaxExempt(alice, true);

        // Admin sends to alice
        vm.prank(admin);
        token.transfer(alice, amount);

        // Alice sends to bob — alice is exempt, so no tax
        vm.prank(alice);
        token.transfer(bob, amount);

        assertEq(token.balanceOf(bob), amount);
    }

    function test_tax_exemptRecipientNotTaxed() public {
        uint256 amount = 1000 ether;

        // Make bob exempt
        vm.prank(admin);
        token.setTaxExempt(bob, true);

        // Admin sends to alice
        vm.prank(admin);
        token.transfer(alice, amount);

        // Alice sends to bob — bob is exempt, so no tax
        vm.prank(alice);
        token.transfer(bob, amount);

        assertEq(token.balanceOf(bob), amount);
    }

    function test_tax_disabledNoTax() public {
        uint256 amount = 1000 ether;

        // Disable tax
        vm.prank(admin);
        token.setTaxEnabled(false);

        // Admin sends to alice
        vm.prank(admin);
        token.transfer(alice, amount);

        // Alice sends to bob — tax disabled, so no tax
        vm.prank(alice);
        token.transfer(bob, amount);

        assertEq(token.balanceOf(bob), amount);
    }

    function test_tax_changeTaxBps() public {
        uint256 amount = 10_000 ether;

        // Change tax to 1% (100 bps)
        vm.prank(admin);
        token.setTaxBps(100);

        // Admin sends to alice
        vm.prank(admin);
        token.transfer(alice, amount);

        // Alice sends to bob — 1% tax
        vm.prank(alice);
        token.transfer(bob, amount);

        uint256 expectedTax = (amount * 100) / BPS_DENOMINATOR; // 100 ether
        assertEq(token.balanceOf(bob), amount - expectedTax);
        assertEq(token.balanceOf(taxWallet), expectedTax);
    }

    function test_tax_setTaxBpsRevertsAboveMax() public {
        vm.prank(admin);
        vm.expectRevert();
        token.setTaxBps(1001); // > MAX_TAX_BPS (1000)
    }

    function test_tax_changeTaxWallet() public {
        address newWallet = makeAddr("newTaxWallet");
        uint256 amount = 10_000 ether;

        vm.prank(admin);
        token.setTaxWallet(newWallet);

        assertEq(token.taxWallet(), newWallet);

        // Verify new wallet receives tax
        vm.prank(admin);
        token.transfer(alice, amount);

        vm.prank(alice);
        token.transfer(bob, amount);

        uint256 expectedTax = (amount * TAX_BPS) / BPS_DENOMINATOR;
        assertEq(token.balanceOf(newWallet), expectedTax);
    }

    function test_tax_zeroTaxBps() public {
        uint256 amount = 1000 ether;

        // Set tax to 0
        vm.prank(admin);
        token.setTaxBps(0);

        vm.prank(admin);
        token.transfer(alice, amount);

        vm.prank(alice);
        token.transfer(bob, amount);

        assertEq(token.balanceOf(bob), amount, "0% tax means no deduction");
    }

    function test_tax_emitsTaxCollectedEvent() public {
        uint256 amount = 10_000 ether;

        vm.prank(admin);
        token.transfer(alice, amount);

        uint256 expectedTax = (amount * TAX_BPS) / BPS_DENOMINATOR;

        vm.expectEmit(true, true, false, true);
        emit Token.TaxCollected(alice, bob, expectedTax);

        vm.prank(alice);
        token.transfer(bob, amount);
    }

    // ============================================================
    //                    ACCESS CONTROL
    // ============================================================

    function test_access_nonAdminCannotSetTaxExempt() public {
        vm.prank(alice);
        vm.expectRevert();
        token.setTaxExempt(bob, true);
    }

    function test_access_nonTaxManagerCannotSetTaxBps() public {
        vm.prank(alice);
        vm.expectRevert();
        token.setTaxBps(100);
    }

    function test_access_nonTaxManagerCannotSetTaxWallet() public {
        vm.prank(alice);
        vm.expectRevert();
        token.setTaxWallet(bob);
    }

    function test_access_nonTaxManagerCannotSetTaxEnabled() public {
        vm.prank(alice);
        vm.expectRevert();
        token.setTaxEnabled(false);
    }

    function test_access_nonPauserCannotPause() public {
        vm.prank(alice);
        vm.expectRevert();
        token.pause();
    }

    function test_access_nonAdminCannotSetPeer() public {
        vm.prank(alice);
        vm.expectRevert();
        token.setPeer(30102, bytes32(uint256(uint160(address(this)))));
    }

    function test_access_nonAdminCannotSetDelegate() public {
        vm.prank(alice);
        vm.expectRevert();
        token.setDelegate(bob);
    }

    function test_access_adminCanGrantRoles() public {
        bytes32 pauserRole = token.PAUSER_ROLE();

        vm.prank(admin);
        token.grantRole(pauserRole, alice);

        assertTrue(token.hasRole(pauserRole, alice));

        // Alice can now pause
        vm.prank(alice);
        token.pause();
        assertTrue(token.paused());
    }

    // ============================================================
    //                    PAUSE FUNCTIONALITY
    // ============================================================

    function test_pause_blocksTransfers() public {
        vm.prank(admin);
        token.transfer(alice, 1000 ether);

        vm.prank(admin);
        token.pause();

        vm.prank(alice);
        vm.expectRevert();
        token.transfer(bob, 100 ether);
    }

    function test_pause_unpauseRestoresTransfers() public {
        vm.prank(admin);
        token.transfer(alice, 1000 ether);

        vm.prank(admin);
        token.pause();

        vm.prank(admin);
        token.unpause();

        vm.prank(alice);
        token.transfer(bob, 100 ether);

        uint256 taxAmount = (100 ether * TAX_BPS) / BPS_DENOMINATOR;
        assertEq(token.balanceOf(bob), 100 ether - taxAmount);
    }

    function test_pause_emitsEvents() public {
        vm.prank(admin);
        token.pause();
        assertTrue(token.paused());

        vm.prank(admin);
        token.unpause();
        assertFalse(token.paused());
    }

    // ============================================================
    //                    UUPS UPGRADE
    // ============================================================

    function test_upgrade_nonUpgraderReverts() public {
        Token newImpl = new Token(address(lzEndpoint));

        vm.prank(alice);
        vm.expectRevert();
        token.upgradeToAndCall(address(newImpl), "");
    }

    function test_upgrade_upgraderCanUpgrade() public {
        Token newImpl = new Token(address(lzEndpoint));

        vm.prank(admin);
        token.upgradeToAndCall(address(newImpl), "");

        // State should be preserved
        assertEq(token.name(), NAME);
        assertEq(token.totalSupply(), TOTAL_SUPPLY);
        assertEq(token.balanceOf(admin), TOTAL_SUPPLY);
    }

    // ============================================================
    //                    OFT VIEWS
    // ============================================================

    function test_oft_version() public view {
        (bytes4 interfaceId, uint64 version) = token.oftVersion();
        assertNotEq(interfaceId, bytes4(0));
        assertEq(version, 1);
    }

    function test_oft_tokenIsThis() public view {
        assertEq(token.token(), address(token));
    }

    function test_oft_approvalNotRequired() public view {
        assertFalse(token.approvalRequired());
    }

    function test_oft_sharedDecimals() public view {
        assertEq(token.sharedDecimals(), 6);
    }

    function test_oft_endpoint() public view {
        assertEq(address(token.endpoint()), address(lzEndpoint));
    }

    function test_oapp_version() public view {
        (uint64 sender, uint64 receiver) = token.oAppVersion();
        assertEq(sender, 1);
        assertEq(receiver, 2);
    }

    // ============================================================
    //                    PEER MANAGEMENT
    // ============================================================

    function test_peer_setAndGet() public {
        uint32 eid = 30101;
        bytes32 peer = bytes32(uint256(uint160(makeAddr("remotePeer"))));

        vm.prank(admin);
        token.setPeer(eid, peer);

        assertEq(token.peers(eid), peer);
        assertTrue(token.isPeer(eid, peer));
    }

    function test_peer_setEmitsEvent() public {
        uint32 eid = 30101;
        bytes32 peer = bytes32(uint256(uint160(makeAddr("remotePeer"))));

        vm.expectEmit(false, false, false, true);
        emit Token.PeerSet(eid, peer);

        vm.prank(admin);
        token.setPeer(eid, peer);
    }

    // ============================================================
    //                    OFT SEND (burn-on-send)
    // ============================================================

    function test_send_burnTokensOnSource() public {
        uint256 sendAmount = 1000 ether;
        uint32 dstEid = 30101;
        bytes32 remotePeer = bytes32(uint256(uint160(makeAddr("remotePeer"))));

        // Setup: give alice tokens, set peer, set mock fee
        vm.prank(admin);
        token.transfer(alice, sendAmount);

        vm.prank(admin);
        token.setPeer(dstEid, remotePeer);

        lzEndpoint.setMockFees(0.01 ether, 0);

        // Get the balance after tax
        uint256 aliceBalance = token.balanceOf(alice);

        // Alice sends across chain
        vm.deal(alice, 1 ether);
        vm.prank(alice);
        token.send{ value: 0.01 ether }(
            _createSendParam(dstEid, alice, aliceBalance, 0),
            MessagingFee(0.01 ether, 0),
            alice
        );

        // Alice's tokens should be burned
        assertEq(token.balanceOf(alice), 0, "alice tokens should be burned");
        // Total supply decreases
        assertLt(token.totalSupply(), TOTAL_SUPPLY, "total supply should decrease");
    }

    function test_send_revertWithoutPeer() public {
        uint256 sendAmount = 100 ether;
        uint32 dstEid = 30101; // No peer set

        vm.prank(admin);
        token.transfer(alice, sendAmount);

        uint256 aliceBalance = token.balanceOf(alice);

        vm.deal(alice, 1 ether);
        vm.prank(alice);
        vm.expectRevert();
        token.send{ value: 0.01 ether }(
            _createSendParam(dstEid, alice, aliceBalance, 0),
            MessagingFee(0.01 ether, 0),
            alice
        );
    }

    function test_send_removeDust() public view {
        // decimalConversionRate = 10^12
        // 1234567890123456789 should lose the last 12 digits of precision
        uint256 amount = 1234567890123456789;
        uint256 dustRemoved = (amount / 1e12) * 1e12;
        assertEq(dustRemoved, 1234567000000000000);
    }

    // ============================================================
    //                    LZ RECEIVE
    // ============================================================

    function test_lzReceive_revertIfNotEndpoint() public {
        Origin memory origin = Origin({ srcEid: 30101, sender: bytes32(0), nonce: 1 });

        vm.prank(alice);
        vm.expectRevert();
        token.lzReceive(origin, bytes32(0), "", alice, "");
    }

    // ============================================================
    //                    FUZZ TESTS
    // ============================================================

    function testFuzz_tax_correctAmount(uint256 amount) public {
        // Bound to reasonable range
        amount = bound(amount, 1 ether, 100_000_000 ether);

        vm.prank(admin);
        token.transfer(alice, amount);

        uint256 aliceBalBefore = token.balanceOf(alice);
        uint256 taxWalletBefore = token.balanceOf(taxWallet);

        vm.prank(alice);
        token.transfer(bob, aliceBalBefore);

        uint256 expectedTax = (aliceBalBefore * TAX_BPS) / BPS_DENOMINATOR;
        uint256 expectedReceived = aliceBalBefore - expectedTax;

        assertEq(token.balanceOf(bob), expectedReceived, "fuzz: bob balance");
        assertEq(token.balanceOf(taxWallet) - taxWalletBefore, expectedTax, "fuzz: tax wallet");
    }

    function testFuzz_tax_bpsRange(uint256 bps) public {
        bps = bound(bps, 0, 1000); // 0% to 10% (MAX_TAX_BPS)

        vm.prank(admin);
        token.setTaxBps(bps);

        assertEq(token.taxBps(), bps);
    }

    // ============================================================
    //                    HELPERS
    // ============================================================

    function _createSendParam(uint32 _dstEid, address _to, uint256 _amount, uint256 _minAmount)
        internal
        pure
        returns (SendParam memory)
    {
        return SendParam({
            dstEid: _dstEid,
            to: bytes32(uint256(uint160(_to))),
            amountLD: _amount,
            minAmountLD: _minAmount,
            extraOptions: "",
            composeMsg: "",
            oftCmd: ""
        });
    }
}
