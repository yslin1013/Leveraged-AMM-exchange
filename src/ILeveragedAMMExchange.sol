// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ILeveragedAMMExchange {
    /* ================== Type Declarations ================== */

    /// @title The mode of the position.
    /// @dev CROSS: The user's position is shared across all token swaps.
    /// @dev ISOLATED: The user's position is isolated to each token swap.
    enum Mode {
        CROSS,
        ISOLATED
    }

    /// @title The pair of tokens.
    /// @param tradingPairSymbol The symbol of the trading pair.
    /// @param reserveA The reserve amount of token A.
    /// @param reserveB The reserve amount of token B.
    struct Pair {
        string tradingPairSymbol;
        uint256 reserveA;
        uint256 reserveB;
    }

    /// @title The order to swap tokens.
    /// @param tokenA The address of token A.
    /// @param tokenB The address of token B.
    /// @param amount The amount of token A to swap.
    /// @param leverage The leverage to use.
    /// @param positionMode The mode of the position.
    /// @param reducePosition Whether to reduce the position (CROSS mode only).
    /// @param closePosition Whether to close the position (ISOLATED node only).
    /// @param closePosIndex The index of the position to close (use if closePosition is true).
    struct Order {
        address tokenA;
        address tokenB;
        uint256 amount;
        uint8 leverage;
        Mode positionMode;
        bool reducePosition;
        bool closePosition;
        uint256 closePosIndex;
    }

    /// @title The position of the user.
    /// @param tradingPairSymbol The symbol of the trading pair.
    /// @param collateralAmount The amount of collateral tokens.
    /// @param collateralWorthValue The collateral worth value of the position.
    /// @param positionValue The value of the position (target tokens amount).
    /// @param leverage The leverage of the position.
    struct Position {
        string tradingPairSymbol;
        uint256 collateralAmount;
        uint256 collateralWorthValue;
        uint256 positionValue;
        uint8 leverage;
    }

    /* ================== Events & Errors ================== */

    event Deposit(address indexed account, address indexed collateralToken, uint256 amount);
    event Withdraw(address indexed account, address indexed collateralToken, uint256 amount);
    event Swap(
        address indexed account,
        address indexed tokenA,
        address indexed tokenB,
        uint256 amountIn,
        uint256 amountOut,
        uint8 leverage,
        Mode positionMode
    );

    error PairAlreadyExists();
    error InvalidLeverage();
    error InvalidTokenAmount();
    error InvalidTokenAddress();
    error InsufficientAmount(uint256 tokenAmount);
    error InsufficientAccountValue(uint256 leveragedAmount, uint256 remainingValue);

    /* ================== Functions ================== */

    /// @notice Deposit collateral tokens to the contract.
    /// @param collateralToken The address of the collateral token.
    /// @param amount The amount of collateral tokens to deposit.
    function deposit(address collateralToken, uint256 amount) external;

    /// @notice Withdraw collateral tokens from the contract.
    /// @param collateralToken The address of the collateral token.
    /// @param amount The amount of collateral tokens to withdraw.
    function withdraw(address collateralToken, uint256 amount) external;

    /// @notice Swap tokens with leverage.
    /// @param swapOrder The order to swap tokens.
    function swap(Order calldata swapOrder) external;

    /// @notice Create a pair of tokens.
    /// @param tokenA The address of token A.
    /// @param tokenB The address of token B.
    /// @param reserveA The reserve amount of token A.
    /// @param reserveB The reserve amount of token B.
    function createPair(address tokenA, address tokenB, uint256 reserveA, uint256 reserveB) external;

    /// @notice Add reserves to a pair of tokens.
    /// @param tokenA The address of token A.
    /// @param tokenB The address of token B.
    /// @param amountA The amount of token A to add to the reserve.
    /// @param amountB The amount of token B to add to the reserve.
    function addReserves(address tokenA, address tokenB, uint256 amountA, uint256 amountB) external;

    /// @notice Get the position worth value of an account.
    /// @param account The address of the account.
    /// @param tokenA The address of token A.
    /// @param tokenB The address of token B.
    /// @return The worth value of the position.
    function getPositionWorthValue(address account, address tokenA, address tokenB) external view returns (uint256);

    /// @notice Get the trading pair price of two tokens.
    /// @param tokenA The address of token A.
    /// @param tokenB The address of token B.
    /// @return The trading pair price.
    function getPairPrice(address tokenA, address tokenB) external view returns (uint256);

    /// @notice Get the amount of token B from token A.
    /// @param tokenA The address of token A.
    /// @param tokenB The address of token B.
    /// @param amountIn The amount of token A to swap.
    /// @param leverage The leverage to use.
    /// @return The amount of token B to receive.
    function getAmountOutFromIn(address tokenA, address tokenB, uint256 amountIn, uint8 leverage)
        external
        view
        returns (uint256);

    /// @notice Get the amount of token A to swap for token B.
    /// @param tokenA The address of token A.
    /// @param tokenB The address of token B.
    /// @param amountOut The amount of token B to receive.
    /// @param leverage The leverage to use.
    /// @return The amount of token A to swap.
    function getAmountInForOut(address tokenA, address tokenB, uint256 amountOut, uint8 leverage)
        external
        view
        returns (uint256);

    /// @notice Get the returned collateral amount when reducing/closing a position.
    /// @param tokenA The address of token A.
    /// @param tokenB The address of token B.
    /// @param amount The amount of token B to repay.
    /// @param leverage The leverage used.
    /// @return The returned collateral amount.
    function getAmountCollateralReturn(address tokenA, address tokenB, uint256 amount, uint8 leverage)
        external
        view
        returns (uint256, uint256);

    /// @notice Get the remaining value of an account.
    /// @param account The address of the account.
    /// @param tokenA The address of token A.
    /// @param tokenB The address of token B.
    /// @return The remaining value of the account.
    function getAccountRemainingValue(address account, address tokenA, address tokenB)
        external
        view
        returns (uint256);

    /// @notice Get the position ID of the trading pair.
    /// @param tokenA The address of token A.
    /// @param tokenB The address of token B.
    /// @return The position ID.
    function getPositionId(address tokenA, address tokenB) external pure returns (bytes32);
}
