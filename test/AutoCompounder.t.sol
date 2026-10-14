// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Currency, CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {PosmTestSetup} from "v4-periphery/test/shared/PosmTestSetup.sol";
import {PositionConfig} from "v4-periphery/test/shared/PositionConfig.sol";
import {IERC721} from "forge-std/interfaces/IERC721.sol";

import {AutoCompounder} from "../src/AutoCompounder.sol";

contract AutoCompounderTest is PosmTestSetup {
    uint256 constant PERCENTAGE = 2_000; // 0.2%
    uint256 constant LIQUIDITY = 100e18;

    AutoCompounder compounder;
    PositionConfig config;
    uint256 tokenId;

    address alice = makeAddr("ALICE");
    address recipient = makeAddr("RECIPIENT");

    function setUp() public {
        deployFreshManagerAndRouters();
        deployMintAndApprove2Currencies();
        (key,) = initPool(currency0, currency1, IHooks(address(0)), 3000, SQRT_PRICE_1_1);
        deployAndApprovePosm(manager);

        compounder = new AutoCompounder(lpm, PERCENTAGE);

        config = PositionConfig({poolKey: key, tickLower: -120, tickUpper: 120});
        tokenId = _mintApproved(config, LIQUIDITY);
    }

    function test_compound_feesCoverIncrease() public {
        donateRouter.donate(key, 1e18, 1e18, ZERO_BYTES);

        _compound(tokenId, currency0, currency1, 0);

        assertEq(lpm.getPositionLiquidity(tokenId), LIQUIDITY + LIQUIDITY * PERCENTAGE / 1e6);
        // Fees pay for the increase; the surplus goes to the recipient and nothing is left in PositionManager.
        assertGt(currency0.balanceOf(recipient), 0.99e18);
        assertGt(currency1.balanceOf(recipient), 0.99e18);
        assertLt(currency0.balanceOf(recipient), 1e18);
        assertLt(currency1.balanceOf(recipient), 1e18);
        assertEq(currency0.balanceOf(address(lpm)), 0);
        assertEq(currency1.balanceOf(address(lpm)), 0);
    }

    function test_compound_searcherTopsUp() public {
        // No fees accrued: the searcher pays for the increase and gets the overpayment back.
        IERC20(Currency.unwrap(currency0)).transfer(address(lpm), 1e18);
        IERC20(Currency.unwrap(currency1)).transfer(address(lpm), 1e18);

        _compound(tokenId, currency0, currency1, 0);

        assertEq(lpm.getPositionLiquidity(tokenId), LIQUIDITY + LIQUIDITY * PERCENTAGE / 1e6);
        assertLt(currency0.balanceOf(recipient), 1e18);
        assertLt(currency1.balanceOf(recipient), 1e18);
        assertEq(currency0.balanceOf(address(lpm)), 0);
        assertEq(currency1.balanceOf(address(lpm)), 0);
    }

    function test_compound_native() public {
        vm.deal(address(this), 10e18);
        (PoolKey memory nativeKey,) =
            initPool(CurrencyLibrary.ADDRESS_ZERO, currency1, IHooks(address(0)), 3000, SQRT_PRICE_1_1);
        PositionConfig memory nativeConfig = PositionConfig({poolKey: nativeKey, tickLower: -120, tickUpper: 120});

        uint256 nativeTokenId = lpm.nextTokenId();
        mintWithNative(SQRT_PRICE_1_1, nativeConfig, LIQUIDITY, alice, ZERO_BYTES);
        vm.prank(alice);
        IERC721(address(lpm)).approve(address(compounder), nativeTokenId);

        IERC20(Currency.unwrap(currency1)).transfer(address(lpm), 1e18);
        _compound(nativeTokenId, CurrencyLibrary.ADDRESS_ZERO, currency1, 1e18);

        assertEq(lpm.getPositionLiquidity(nativeTokenId), LIQUIDITY + LIQUIDITY * PERCENTAGE / 1e6);
        assertGt(recipient.balance, 0.99e18);
        assertLt(recipient.balance, 1e18);
        assertEq(address(lpm).balance, 0);
        assertEq(currency1.balanceOf(address(lpm)), 0);
    }

    function _mintApproved(PositionConfig memory _config, uint256 liquidity) internal returns (uint256 id) {
        id = lpm.nextTokenId();
        mint(_config, liquidity, alice, ZERO_BYTES);
        vm.prank(alice);
        IERC721(address(lpm)).approve(address(compounder), id);
    }

    function _compound(uint256 id, Currency c0, Currency c1, uint256 value) internal {
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = id;
        address[] memory currencies = new address[](2);
        currencies[0] = Currency.unwrap(c0);
        currencies[1] = Currency.unwrap(c1);
        compounder.compound{value: value}(tokenIds, currencies, recipient, block.timestamp);
    }
}
