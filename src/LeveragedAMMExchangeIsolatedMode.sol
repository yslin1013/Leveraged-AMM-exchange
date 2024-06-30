// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {LeveragedAMMExchange} from "./LeveragedAMMExchange.sol";

/// @title Leveraged AMM Exchange contract
/// @notice This contract is a simplified version of a leveraged AMM exchange.
/// @dev The contract allows users to deposit tokens, create arbitrary pairs, and swap tokens with leverage.
///  The contract also provides functions to get the account position value and remaining value.
///  The contract also provides functions to get the pair price, amount in/out, and returned collateral amount.
///  Users can open and close positions in isolated margin mode.
///   In isolated margin mode, the user's position is isolated to each token swap.
///     `OPEN`: buy tokens, `CLOSE`: sell all tokens in a specific single swap.
contract LeveragedAMMExchangeIsolatedMode is LeveragedAMMExchange {
    /* ================== State Varaibles ================== */

    /// @notice The mapping of user positions in isolated mode.
    mapping(address => mapping(bytes32 => Position[])) public positionsIsolated;

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
        if (swapOrder.positionMode == Mode.ISOLATED) {
            if (!swapOrder.closePosition) {
                _swapIsolatedOpen(swapOrder.tokenA, swapOrder.tokenB, swapOrder.amount, swapOrder.leverage);
            } else {
                _swapIsolatedClose(swapOrder.tokenA, swapOrder.tokenB, swapOrder.closePosIndex);
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
        Position[] memory posIsolated = positionsIsolated[account][positionId];
        uint256 collateralWorthPositionValue = 0;
        for (uint256 i = 0; i < posIsolated.length; i++) {
            collateralWorthPositionValue += posIsolated[i].collateralWorthValue;
        }
        return collateralWorthPositionValue;
    }

    /// @notice Get the account position info in isolated mode.
    /// @param account The address of the account.
    /// @param tokenA The address of token A.
    /// @param tokenB The address of token B.
    /// @param posIndex The index of the position in the list.
    /// @return The position info.
    function getPositionIsolated(address account, address tokenA, address tokenB, uint256 posIndex)
        external
        view
        returns (Position memory)
    {
        bytes32 positionId = keccak256(abi.encodePacked(tokenA, tokenB));
        return positionsIsolated[account][positionId][posIndex];
    }

    /// @notice Get the number of isolated positions for a specific trading pair.
    /// @param account The address of the account.
    /// @param tokenA The address of token A.
    /// @param tokenB The address of token B.
    /// @return The number of isolated positions.
    function getPositionsIsolatedLength(address account, address tokenA, address tokenB)
        external
        view
        returns (uint256)
    {
        bytes32 positionId = keccak256(abi.encodePacked(tokenA, tokenB));
        return positionsIsolated[account][positionId].length;
    }

    /// @notice Get the remaining value of an account.
    /// @param account The address of the account.
    /// @param tokenA The address of token A.
    /// @param tokenB The address of token B.
    /// @return The remaining value of the account.
    function getAccountRemainingValue(address account, address tokenA, address tokenB) public view returns (uint256) {
        bytes32 positionId = keccak256(abi.encodePacked(tokenA, tokenB));
        Position[] memory posIsolated = positionsIsolated[account][positionId];
        uint256 depositedAmount = balances[account][tokenA];
        uint256 collateralWorthPositionValue = 0;
        for (uint256 i = 0; i < posIsolated.length; i++) {
            depositedAmount += posIsolated[i].collateralAmount;
            collateralWorthPositionValue += posIsolated[i].collateralWorthValue;
        }
        return depositedAmount * MAX_LEVERAGE - collateralWorthPositionValue;
    }

    /* ================== Internal Functions ================== */

    /// @notice Swap tokens in isolated mode (open position).
    /// @param tokenA The address of token A.
    /// @param tokenB The address of token B.
    /// @param amount The amount of token A to swap.
    /// @param leverage The leverage to use.
    function _swapIsolatedOpen(address tokenA, address tokenB, uint256 amount, uint8 leverage) internal {
        bytes32 positionId = keccak256(abi.encodePacked(tokenA, tokenB));
        Position[] storage posIsolatedList = positionsIsolated[msg.sender][positionId];
        uint256 amountOut = getAmountOutFromIn(tokenA, tokenB, amount, leverage);
        if (amountOut == 0) revert InvalidTokenAmount();

        uint256 leveragedAmount = amount * leverage;
        uint256 remainingValue = getAccountRemainingValue(msg.sender, tokenA, tokenB);
        if (leveragedAmount > remainingValue) revert InsufficientAccountValue(leveragedAmount, remainingValue);

        posIsolatedList.push(
            Position({
                tradingPairSymbol: string(
                    abi.encodePacked(IERC20Metadata(tokenB).symbol(), "/", IERC20Metadata(tokenA).symbol())
                ),
                collateralAmount: amount,
                collateralWorthValue: leveragedAmount,
                positionValue: amountOut,
                leverage: leverage
            })
        );

        balances[msg.sender][tokenA] -= amount;
        pairs[tokenA][tokenB].reserveA += leveragedAmount;
        pairs[tokenA][tokenB].reserveB -= amountOut;

        emit Swap(msg.sender, tokenA, tokenB, amount, amountOut, leverage, Mode.ISOLATED);
    }

    /// @notice Swap tokens in isolated mode (close position).
    /// @param tokenA The address of token A.
    /// @param tokenB The address of token B.
    /// @param closePosIndex The index of the position to close.
    function _swapIsolatedClose(address tokenA, address tokenB, uint256 closePosIndex) internal {
        bytes32 positionId = keccak256(abi.encodePacked(tokenA, tokenB));
        Position[] storage posIsolatedList = positionsIsolated[msg.sender][positionId];
        Position memory position = posIsolatedList[closePosIndex];
        (uint256 leveragedAmount, uint256 amountIn) =
            getAmountCollateralReturn(tokenA, tokenB, position.positionValue, position.leverage);
        if (leveragedAmount == 0) revert InvalidTokenAmount();

        balances[msg.sender][tokenA] += amountIn;
        pairs[tokenA][tokenB].reserveA -= leveragedAmount;
        pairs[tokenA][tokenB].reserveB += position.positionValue;

        posIsolatedList[closePosIndex] = posIsolatedList[posIsolatedList.length - 1];
        posIsolatedList.pop();

        emit Swap(msg.sender, tokenB, tokenA, position.positionValue, amountIn, position.leverage, Mode.ISOLATED);
    }
}
