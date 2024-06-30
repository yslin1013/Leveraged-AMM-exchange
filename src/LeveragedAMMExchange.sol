// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {ILeveragedAMMExchange} from "./ILeveragedAMMExchange.sol";

abstract contract LeveragedAMMExchange is ILeveragedAMMExchange, ReentrancyGuard {
    /* ================== State Varaibles ================== */

    /// @notice The maximum leverage allowed.
    /// @notice The number of trading pairs created.
    uint8 public constant MAX_LEVERAGE = 10;
    uint256 public pairCount = 0;

    /// @notice The mapping of trading pairs.
    /// @notice The mapping of user balances (deposited collateral tokens).
    mapping(address => mapping(address => Pair)) public pairs;
    mapping(address => mapping(address => uint256)) public balances;

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

    /* ================== External Functions ================== */

    /// @notice Deposit collateral tokens to the contract.
    /// @param collateralToken The address of the collateral token.
    /// @param amount The amount of collateral tokens to deposit.
    function deposit(address collateralToken, uint256 amount) external nonReentrant {
        balances[msg.sender][collateralToken] += amount;
        IERC20Metadata(collateralToken).transferFrom(msg.sender, address(this), amount);
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

    function swap(Order calldata swapOrder) external virtual;

    /* ================== External View Functions ================== */

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
}
