// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {PaymentLib} from "../src/libraries/PaymentLib.sol";

/**
 * @title  MockERC20
 * @notice Minimal standard ERC20 with an open `mint`, used only to exercise PaymentLib.collect.
 * @dev    Self-contained: avoids coupling these tests to the separate euro-token Foundry project.
 */
contract MockERC20 is ERC20 {
    constructor() ERC20("Mock EURT", "mEURT") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/**
 * @title  PaymentLibHarness
 * @notice Test-only wrapper exposing PaymentLib's internal `collect` as an external function.
 * @dev    Because the library is inlined here, the token sees THIS contract as the spender, so the
 *         payer must approve the harness address.
 */
contract PaymentLibHarness {
    using PaymentLib for IERC20;

    function collect(IERC20 token, address from, address to, uint256 amount) external {
        token.collect(from, to, amount);
    }
}

/**
 * @title  PaymentLib test suite
 * @notice Isolated unit tests for PaymentLib: the pull (approve + transferFrom) settlement path.
 */
contract PaymentLibTest is Test {
    PaymentLibHarness internal harness;
    MockERC20 internal token;

    address internal payer = makeAddr("payer");
    address internal seller = makeAddr("seller");

    function setUp() public {
        harness = new PaymentLibHarness();
        token = new MockERC20();
        token.mint(payer, 100e6);
    }

    /// @notice With a prior allowance, collect pulls funds from payer to seller and spends the allowance.
    function test_collect_transfers() public {
        vm.startPrank(payer);
        token.approve(address(harness), 30e6);
        vm.stopPrank();

        harness.collect(IERC20(address(token)), payer, seller, 30e6);

        assertEq(token.balanceOf(seller), 30e6, "seller received");
        assertEq(token.balanceOf(payer), 70e6, "payer debited");
        assertEq(token.allowance(payer, address(harness)), 0, "allowance consumed");
    }

    /// @notice Without an allowance the pull reverts (documents the approve-first requirement).
    function test_collect_requires_allowance() public {
        vm.expectRevert();
        harness.collect(IERC20(address(token)), payer, seller, 30e6);
    }
}
