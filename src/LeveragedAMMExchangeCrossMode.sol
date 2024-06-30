// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {LeveragedAMMExchange} from "./LeveragedAMMExchange.sol";

/// @title Leveraged AMM Exchange contract in cross margin mode.
/// @notice This contract is a simplified version of a leveraged AMM exchange.
/// @dev The contract allows users to deposit tokens, create arbitrary pairs, and swap tokens with leverage.
///  The contract also provides functions to get the account position value and remaining value.
///  The contract also provides functions to get the pair price, amount in/out, and returned collateral amount.
///  Users can open and reduce position in cross margin mode.
///   In cross margin mode, the user's position is shared across all token swaps.
///     `OPEN`: buy tokens, `REDUCE`: sell tokens (part of or all).
contract LeveragedAMMExchangeCrossMode is LeveragedAMMExchange {
    /* ================== State Varaibles ================== */

    /// @notice The mapping of user positions in cross mode.
    mapping(address => mapping(bytes32 => Position)) public positionCross;

    constructor() {}

    /* ================== External Functions ================== */

    /// @notice Swap tokens with leverage.
    /// @param swapOrder The order to swap tokens.
    function swap(Order calldata swapOrder)
        external
        override
        isValidLeverage(swapOrder.leverage)
        isValidAmount(swapOrder.amount)
        isValidAddress(swapOrder.tokenA)
        isValidAddress(swapOrder.tokenB)
    {
        uint256 balance = balances[msg.sender][swapOrder.tokenA];
        if (balance < swapOrder.amount) revert InsufficientAmount(balance);
        if (swapOrder.positionMode == Mode.CROSS) {
            if (!swapOrder.reducePosition) {
                _swapCrossOpen(swapOrder.tokenA, swapOrder.tokenB, swapOrder.amount);
            } else {
                _swapCrossReduce(swapOrder.tokenA, swapOrder.tokenB, swapOrder.amount);
            }
        }
    }

    /* ================== External View Functions ================== */

    /// @notice Get the position worth value of an account.
    /// @param account The address of the account.
    /// @param tokenA The address of token A.
    /// @param tokenB The address of token B.
    /// @return The worth value of the position.
    function getPositionWorthValue(address account, address tokenA, address tokenB) external view returns (uint256) {
        bytes32 positionId = keccak256(abi.encodePacked(tokenA, tokenB));
        Position memory posCross = positionCross[account][positionId];
        uint256 collateralWorthPositionValue = posCross.collateralWorthValue;
        return collateralWorthPositionValue;
    }

    /// @notice Get the account position info in cross mode.
    /// @param account The address of the account.
    /// @param tokenA The address of token A.
    /// @param tokenB The address of token B.
    /// @return The position info.
    function getPositionCross(address account, address tokenA, address tokenB)
        external
        view
        returns (Position memory)
    {
        bytes32 positionId = keccak256(abi.encodePacked(tokenA, tokenB));
        return positionCross[account][positionId];
    }

    /* ================== Public View Functions ================== */

    /// @notice Get the remaining value of an account.
    /// @param account The address of the account.
    /// @param tokenA The address of token A.
    /// @param tokenB The address of token B.
    /// @return The remaining value of the account.
    function getAccountRemainingValue(address account, address tokenA, address tokenB) public view returns (uint256) {
        bytes32 positionId = keccak256(abi.encodePacked(tokenA, tokenB));
        Position memory posCross = positionCross[account][positionId];
        uint256 depositedAmount = balances[account][tokenA];
        if (posCross.positionValue > 0) depositedAmount += posCross.collateralAmount;
        return depositedAmount * MAX_LEVERAGE - posCross.collateralWorthValue;
    }

    /* ================== Internal Functions ================== */

    /// @notice Swap tokens in cross mode (open position).
    /// @param tokenA The address of token A.
    /// @param tokenB The address of token B.
    /// @param amount The amount of token A to swap.
    function _swapCrossOpen(address tokenA, address tokenB, uint256 amount) internal {
        bytes32 positionId = keccak256(abi.encodePacked(tokenA, tokenB));
        Position storage posCross = positionCross[msg.sender][positionId];
        uint256 amountOut = getAmountOutFromIn(tokenA, tokenB, amount, MAX_LEVERAGE);
        if (amountOut == 0) revert InvalidTokenAmount();

        uint256 leveragedAmount = amount * MAX_LEVERAGE;
        uint256 remainingValue = getAccountRemainingValue(msg.sender, tokenA, tokenB);
        if (leveragedAmount > remainingValue) revert InsufficientAccountValue(leveragedAmount, remainingValue);
        if (posCross.leverage == 0) {
            posCross.leverage = MAX_LEVERAGE;
            posCross.tradingPairSymbol =
                string(abi.encodePacked(IERC20Metadata(tokenB).symbol(), "/", IERC20Metadata(tokenA).symbol()));
        }

        posCross.collateralAmount += amount;
        posCross.collateralWorthValue += leveragedAmount;
        posCross.positionValue += amountOut;
        balances[msg.sender][tokenA] -= amount;
        pairs[tokenA][tokenB].reserveA += leveragedAmount;
        pairs[tokenA][tokenB].reserveB -= amountOut;

        emit Swap(msg.sender, tokenA, tokenB, amount, amountOut, MAX_LEVERAGE, Mode.CROSS);
    }

    /// @notice Swap tokens in cross mode (reduce position).
    /// @param tokenA The address of token A.
    /// @param tokenB The address of token B.
    /// @param amount The amount of token B to repay.
    function _swapCrossReduce(address tokenA, address tokenB, uint256 amount) internal {
        bytes32 positionId = keccak256(abi.encodePacked(tokenA, tokenB));
        Position storage posCross = positionCross[msg.sender][positionId];
        (uint256 leveragedAmount, uint256 amountIn) = getAmountCollateralReturn(tokenA, tokenB, amount, MAX_LEVERAGE);
        if (leveragedAmount == 0) revert InvalidTokenAmount();

        posCross.collateralAmount -= amountIn;
        posCross.collateralWorthValue -= leveragedAmount;
        posCross.positionValue -= amount;
        balances[msg.sender][tokenA] += amountIn;
        pairs[tokenA][tokenB].reserveA -= leveragedAmount;
        pairs[tokenA][tokenB].reserveB += amount;

        emit Swap(msg.sender, tokenB, tokenA, amount, amountIn, MAX_LEVERAGE, Mode.CROSS);
    }
}
