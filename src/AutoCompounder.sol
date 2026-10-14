// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IPositionManager} from "v4-periphery/src/interfaces/IPositionManager.sol";
import {Actions} from "v4-periphery/src/libraries/Actions.sol";
import {ActionConstants} from "v4-periphery/src/libraries/ActionConstants.sol";

/// @title AutoCompounder
/// @notice Permissionless compounding for Uniswap v4 positions. Anyone may claim a position's unclaimed fees,
/// but only by increasing that same position's liquidity by PERCENTAGE in the same transaction.
/// Searchers act once fees exceed the cost of the increase plus gas, so positions compound without a permissioned keeper.
/// @dev Position owners opt in by approving this contract on the PositionManager
contract AutoCompounder {
    uint256 public constant PERCENTAGE_DENOMINATOR = 1_000_000;

    IPositionManager public immutable POSITION_MANAGER;
    uint256 public immutable PERCENTAGE;

    constructor(IPositionManager _positionManager, uint256 _percentage) {
        POSITION_MANAGER = _positionManager;
        PERCENTAGE = _percentage;
    }

    /// @notice Adds PERCENTAGE liquidity to each position and sends the net fee surplus to `recipient`.
    /// @dev Pays from the PositionManager's own balance: the caller must transfer the required tokens to PositionManager
    /// (or send ETH as msg.value) earlier in the same transaction if needed. Any balance PositionManager holds in `currencies`
    /// is settled, and everything left over is sent to `recipient`.
    /// @param tokenIds Positions to compound; each must have approved this contract.
    /// @param currencies Every currency used by the positions (address(0) for ETH).
    /// @param recipient Receives the fees left over after paying for the increase.
    /// @param deadline Passed through to PositionManager.modifyLiquidities.
    function compound(uint256[] calldata tokenIds, address[] calldata currencies, address recipient, uint256 deadline)
        external
        payable
    {
        uint256 totalTokenIds = tokenIds.length;
        uint256 totalCurrencies = currencies.length;
        bytes memory actions = new bytes(totalTokenIds + 2 * totalCurrencies);
        bytes[] memory params = new bytes[](totalTokenIds + 2 * totalCurrencies);

        // Fees accrued by each position net against the cost of the increase (no slippage limit: the
        // searcher is expected to do their checks in their own contract if needed).
        for (uint256 i; i < totalTokenIds; i++) {
            actions[i] = bytes1(uint8(Actions.INCREASE_LIQUIDITY));
            params[i] =
                abi.encode(tokenIds[i], _liquidityToAdd(tokenIds[i]), type(uint128).max, type(uint128).max, bytes(""));
        }

        // Settle any debt with tokens already sent to PositionManager, then take whatever surplus remains and send it to recipient.
        for (uint256 i; i < totalCurrencies; i++) {
            actions[totalTokenIds + i] = bytes1(uint8(Actions.SETTLE));
            params[totalTokenIds + i] = abi.encode(currencies[i], ActionConstants.CONTRACT_BALANCE, false);

            actions[totalTokenIds + totalCurrencies + i] = bytes1(uint8(Actions.TAKE));
            params[totalTokenIds + totalCurrencies + i] =
                abi.encode(currencies[i], recipient, ActionConstants.OPEN_DELTA);
        }

        POSITION_MANAGER.modifyLiquidities{value: msg.value}(abi.encode(actions, params), deadline);
    }

    function _liquidityToAdd(uint256 tokenId) private view returns (uint256) {
        return uint256(POSITION_MANAGER.getPositionLiquidity(tokenId)) * PERCENTAGE / PERCENTAGE_DENOMINATOR;
    }
}
