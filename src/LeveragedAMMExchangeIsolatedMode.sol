// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {ILeveragedAMMExchange} from "./ILeveragedAMMExchange.sol";

/// @title Leveraged AMM Exchange contract
/// @notice This contract is a simplified version of a leveraged AMM exchange.
/// @dev The contract allows users to deposit tokens, create arbitrary pairs, and swap tokens with leverage.
///  The contract also provides functions to get the account position value and remaining value.
///  The contract also provides functions to get the pair price, amount in/out, and returned collateral amount.
///  Users can open and close positions in isolated margin mode.
///   In isolated margin mode, the user's position is isolated to each token swap.
///     `OPEN`: buy tokens, `CLOSE`: sell all tokens in a specific single swap.
contract LeveragedAMMExchangeIsolatedMode is ILeveragedAMMExchange, ReentrancyGuard {
    /* ================== State Varaibles ================== */

    /// @notice The maximum leverage allowed.
    /// @notice The number of trading pairs created.
    uint8 public constant MAX_LEVERAGE = 10;
    uint256 public pairCount = 0;

    /// @notice The mapping of trading pairs.
    /// @notice The mapping of user balances (deposited collateral tokens).
    /// @notice The mapping of user positions in isolated mode.
    mapping(address => mapping(address => Pair)) public pairs;
    mapping(address => mapping(address => uint256)) public balances;
    mapping(address => mapping(bytes32 => Position[])) public positionsIsolated;

    /* ================== Modifiers ================== */

    modifier isValidLeverage(uint8 leverage) {
        if (leverage == 0 || leverage > MAX_LEVERAGE) revert InvalidLeverage();
        _;
    }

    modifier isValidAmount(uint256 amount) {
        if (amount == 0) revert InvalidTokenAmount();
        _;
    }

    modifier isValidAddress(address tokenAddress) {
        if (tokenAddress == address(0)) revert InvalidTokenAddress();
        _;
    }

    constructor() {}

    /* ================== External Functions ================== */

    /// @notice Deposit collateral tokens to the contract.
    /// @param collateralToken The address of the collateral token.
    /// @param amount The amount of collateral tokens to deposit.
    function deposit(address collateralToken, uint256 amount) external nonReentrant {
        IERC20Metadata(collateralToken).transferFrom(msg.sender, address(this), amount);
        balances[msg.sender][collateralToken] += amount;
        emit Deposit(msg.sender, collateralToken, amount);
    }

    /// @notice Withdraw collateral tokens from the contract.
    /// @param collateralToken The address of the collateral token.
    /// @param amount The amount of collateral tokens to withdraw.
    function withdraw(address collateralToken, uint256 amount) external nonReentrant {
        uint256 balance = balances[msg.sender][collateralToken];
        if (balance < amount) revert InsufficientAmount(balance);

        balances[msg.sender][collateralToken] -= amount;
        IERC20Metadata(collateralToken).transfer(msg.sender, amount);
        emit Withdraw(msg.sender, collateralToken, amount);
    }

    /// @notice Swap tokens with leverage.
    /// @param swapOrder The order to swap tokens.
    function swap(Order calldata swapOrder)
        external
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

    /// @notice Create a pair of tokens.
    /// @param tokenA The address of token A.
    /// @param tokenB The address of token B.
    /// @param reserveA The reserve amount of token A.
    /// @param reserveB The reserve amount of token B.
    function createPair(address tokenA, address tokenB, uint256 reserveA, uint256 reserveB)
        external
        isValidAmount(reserveA)
        isValidAmount(reserveB)
        isValidAddress(tokenA)
        isValidAddress(tokenB)
    {
        uint256 tokenReserveA = pairs[tokenA][tokenB].reserveA;
        uint256 tokenReserveB = pairs[tokenA][tokenB].reserveB;
        if (tokenReserveA != 0 || tokenReserveB != 0) revert PairAlreadyExists();
        tokenReserveA = pairs[tokenB][tokenA].reserveA;
        tokenReserveB = pairs[tokenB][tokenA].reserveB;
        if (tokenReserveA != 0 || tokenReserveB != 0) revert PairAlreadyExists();

        string memory symbolA = IERC20Metadata(tokenA).symbol();
        string memory symbolB = IERC20Metadata(tokenB).symbol();
        string memory pairSymbol = string(abi.encodePacked(symbolB, "/", symbolA));
        pairs[tokenA][tokenB] = Pair(pairSymbol, reserveA, reserveB); // NOTE: no transferFrom for simplicity
        pairCount++;
    }

    /// @notice Add reserves to a pair of tokens.
    /// @param tokenA The address of token A.
    /// @param tokenB The address of token B.
    /// @param amountA The amount of token A to add to the reserve.
    /// @param amountB The amount of token B to add to the reserve.
    function addReserves(address tokenA, address tokenB, uint256 amountA, uint256 amountB)
        external
        isValidAmount(amountA)
        isValidAmount(amountB)
        isValidAddress(tokenA)
        isValidAddress(tokenB)
    {
        pairs[tokenA][tokenB].reserveA += amountA; // NOTE: no transferFrom for simplicity
        pairs[tokenA][tokenB].reserveB += amountB;
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

    /// @notice Get the trading pair price of two tokens.
    /// @param tokenA The address of token A.
    /// @param tokenB The address of token B.
    /// @return The trading pair price.
    function getPairPrice(address tokenA, address tokenB) external view returns (uint256) {
        Pair memory pair = pairs[tokenA][tokenB];
        uint256 decimalsTokenA = IERC20Metadata(tokenA).decimals();
        uint256 decimalsTokenB = IERC20Metadata(tokenB).decimals();
        uint256 normalizedReserveA = pair.reserveA * (10 ** (18 - decimalsTokenA));
        uint256 normalizedReserveB = pair.reserveB * (10 ** (18 - decimalsTokenB));
        if (normalizedReserveA == 0 || normalizedReserveB == 0) return 0; // NOTE: avoid division by zero
        return normalizedReserveA / normalizedReserveB;
    }

    /// @notice Get the position ID of the trading pair.
    /// @param tokenA The address of token A.
    /// @param tokenB The address of token B.
    /// @return The position ID.
    function getPositionId(address tokenA, address tokenB) external pure returns (bytes32) {
        return keccak256(abi.encodePacked(tokenA, tokenB));
    }

    /* ================== Public View Functions ================== */

    /// @notice Get the amount of token B from token A.
    /// @param tokenA The address of token A.
    /// @param tokenB The address of token B.
    /// @param amountIn The amount of token A to swap.
    /// @param leverage The leverage to use.
    /// @return The amount of token B to receive.
    function getAmountOutFromIn(address tokenA, address tokenB, uint256 amountIn, uint8 leverage)
        public
        view
        returns (uint256)
    {
        Pair memory pair = pairs[tokenA][tokenB];
        uint256 totalInput = amountIn * leverage;
        uint256 newReserveA = pair.reserveA + totalInput;
        if (newReserveA == 0) return 0; // NOTE: avoid exception
        uint256 newReserveB = (pair.reserveA * pair.reserveB) / newReserveA;
        return pair.reserveB - newReserveB;
    }

    /// @notice Get the amount of token A to swap for token B.
    /// @param tokenA The address of token A.
    /// @param tokenB The address of token B.
    /// @param amountOut The amount of token B to receive.
    /// @param leverage The leverage to use.
    /// @return The amount of token A to swap.
    function getAmountInForOut(address tokenA, address tokenB, uint256 amountOut, uint8 leverage)
        public
        view
        returns (uint256)
    {
        Pair memory pair = pairs[tokenA][tokenB];
        if (pair.reserveB <= amountOut || leverage == 0) return 0; // NOTE: avoid exception
        uint256 newReserveB = pair.reserveB - amountOut;
        uint256 newReserveA = (pair.reserveA * pair.reserveB) / newReserveB;
        return (newReserveA - pair.reserveA) / leverage;
    }

    /// @notice Get the returned collateral amount when reducing/closing a position.
    /// @param tokenA The address of token A.
    /// @param tokenB The address of token B.
    /// @param amount The amount of token B to repay.
    /// @param leverage The leverage used.
    /// @return The returned collateral amount.
    function getAmountCollateralReturn(address tokenA, address tokenB, uint256 amount, uint8 leverage)
        public
        view
        returns (uint256, uint256)
    {
        Pair memory pair = pairs[tokenA][tokenB];
        uint256 newReserveB = pair.reserveB + amount;
        if (newReserveB == 0 || leverage == 0) return (0, 0); // NOTE: avoid exception
        uint256 newReserveA = (pair.reserveA * pair.reserveB) / newReserveB;
        if (pair.reserveA <= newReserveA) return (0, 0); // NOTE: avoid exception
        uint256 returnedAmount = pair.reserveA - newReserveA;
        return (returnedAmount, returnedAmount / leverage);
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
