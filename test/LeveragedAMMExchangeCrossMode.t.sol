// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Test, stdError, console} from "forge-std/Test.sol";
import {MyToken} from "../src/tests/MyToken.sol";
import {LeveragedAMMExchangeCrossMode} from "../src/LeveragedAMMExchangeCrossMode.sol";
import {ILeveragedAMMExchange} from "../src/ILeveragedAMMExchange.sol";

contract LeveragedAMMExchangeTest is Test {
    LeveragedAMMExchangeCrossMode public leveragedAMMExchange;
    MyToken public usdcContract;
    MyToken public wethContract;
    address public tokenA;
    address public tokenB;
    string public tradingPairSymbol;
    uint8 public maxLeverage;

    function setUp() public {
        leveragedAMMExchange = new LeveragedAMMExchangeCrossMode();
        usdcContract = new MyToken("USD Coin", "USDC", 6, type(uint256).max);
        wethContract = new MyToken("Wrapped ETH", "WETH", 18, type(uint256).max);
        tokenA = address(usdcContract);
        tokenB = address(wethContract);
        tradingPairSymbol = "WETH/USDC";
        maxLeverage = leveragedAMMExchange.MAX_LEVERAGE();
    }

    function test_MaxLeverage() public view {
        assertEq(leveragedAMMExchange.MAX_LEVERAGE(), 10);
    }

    function test_CreatePair() public {
        assertEq(leveragedAMMExchange.pairCount(), 0);
        leveragedAMMExchange.createPair(tokenA, tokenB, 10000, 1000);
        (string memory pairSymbol, uint256 reserveA, uint256 reserveB) = leveragedAMMExchange.pairs(tokenA, tokenB);
        assertEq(pairSymbol, tradingPairSymbol);
        assertEq(reserveA, 10000);
        assertEq(reserveB, 1000);
        assertEq(leveragedAMMExchange.pairCount(), 1);
    }

    function test_CreatePair_Failed() public {
        leveragedAMMExchange.createPair(tokenA, tokenB, 10000, 1000);
        vm.expectRevert(ILeveragedAMMExchange.InvalidTokenAddress.selector);
        leveragedAMMExchange.createPair(tokenA, address(0), 10000, 1000);
        vm.expectRevert(ILeveragedAMMExchange.InvalidTokenAddress.selector);
        leveragedAMMExchange.createPair(address(0), tokenB, 10000, 1000);
        vm.expectRevert(ILeveragedAMMExchange.InvalidTokenAddress.selector);
        leveragedAMMExchange.createPair(address(0), address(0), 10000, 1000);
        vm.expectRevert(ILeveragedAMMExchange.InvalidTokenAmount.selector);
        leveragedAMMExchange.createPair(tokenA, tokenB, 0, 0);
        vm.expectRevert(ILeveragedAMMExchange.InvalidTokenAmount.selector);
        leveragedAMMExchange.createPair(tokenA, tokenB, 0, 100);
        vm.expectRevert(ILeveragedAMMExchange.InvalidTokenAmount.selector);
        leveragedAMMExchange.createPair(tokenA, tokenB, 1000, 0);
        vm.expectRevert(ILeveragedAMMExchange.PairAlreadyExists.selector);
        leveragedAMMExchange.createPair(tokenA, tokenB, 10000, 1000);
    }

    function test_AddReserves() public {
        leveragedAMMExchange.createPair(tokenA, tokenB, 10000, 1000);
        leveragedAMMExchange.addReserves(tokenA, tokenB, 1000, 100);
        (, uint256 reserveA, uint256 reserveB) = leveragedAMMExchange.pairs(tokenA, tokenB);
        assertEq(reserveA, 11000);
        assertEq(reserveB, 1100);
    }

    function test_AddReserves_Failed() public {
        leveragedAMMExchange.createPair(tokenA, tokenB, 10000, 1000);
        vm.expectRevert(ILeveragedAMMExchange.InvalidTokenAddress.selector);
        leveragedAMMExchange.addReserves(tokenA, address(0), 1000, 100);
        vm.expectRevert(ILeveragedAMMExchange.InvalidTokenAddress.selector);
        leveragedAMMExchange.addReserves(address(0), tokenB, 1000, 100);
        vm.expectRevert(ILeveragedAMMExchange.InvalidTokenAddress.selector);
        leveragedAMMExchange.addReserves(address(0), address(0), 1000, 100);
        vm.expectRevert(ILeveragedAMMExchange.InvalidTokenAmount.selector);
        leveragedAMMExchange.addReserves(tokenA, tokenB, 0, 0);
        vm.expectRevert(ILeveragedAMMExchange.InvalidTokenAmount.selector);
        leveragedAMMExchange.addReserves(tokenA, tokenB, 0, 100);
        vm.expectRevert(ILeveragedAMMExchange.InvalidTokenAmount.selector);
        leveragedAMMExchange.addReserves(tokenA, tokenB, 1000, 0);
    }

    function test_Deposit() public {
        IERC20(tokenA).approve(address(leveragedAMMExchange), 20);
        leveragedAMMExchange.deposit(tokenA, 20);
        assertEq(leveragedAMMExchange.balances(address(this), tokenA), 20);
    }

    function test_Deposit_Failed() public {
        vm.expectRevert();
        leveragedAMMExchange.deposit(tokenA, 20);
    }

    function testFuzz_Deposit(uint256 x) public {
        IERC20(tokenA).approve(address(leveragedAMMExchange), x);
        leveragedAMMExchange.deposit(tokenA, x);
        assertEq(leveragedAMMExchange.balances(address(this), tokenA), x);
    }

    function test_Withdraw() public {
        IERC20(tokenA).approve(address(leveragedAMMExchange), 20);
        leveragedAMMExchange.deposit(tokenA, 20);
        assertEq(leveragedAMMExchange.balances(address(this), tokenA), 20);
        leveragedAMMExchange.withdraw(tokenA, 10);
        assertEq(leveragedAMMExchange.balances(address(this), tokenA), 10);
    }

    function test_Withdraw_Failed() public {
        IERC20(tokenA).approve(address(leveragedAMMExchange), 20);
        leveragedAMMExchange.deposit(tokenA, 20);
        vm.expectRevert(abi.encodeWithSelector(ILeveragedAMMExchange.InsufficientAmount.selector, 20));
        leveragedAMMExchange.withdraw(tokenA, 30);
    }

    function testFuzz_Withdraw(uint256 x) public {
        IERC20(tokenA).approve(address(leveragedAMMExchange), x);
        leveragedAMMExchange.deposit(tokenA, x);
        assertEq(leveragedAMMExchange.balances(address(this), tokenA), x);
        leveragedAMMExchange.withdraw(tokenA, x);
        assertEq(leveragedAMMExchange.balances(address(this), tokenA), 0);
    }

    function test_GetPairPrice() public {
        assertEq(leveragedAMMExchange.getPairPrice(tokenA, tokenB), 0);
        leveragedAMMExchange.createPair(tokenA, tokenB, 1000000, 1000000000000000);
        uint256 price = leveragedAMMExchange.getPairPrice(tokenA, tokenB);
        assertEq(price, 1000);
    }

    function test_GetPositionId() public {
        leveragedAMMExchange.createPair(tokenA, tokenB, 10000, 1000);
        bytes32 positionId = leveragedAMMExchange.getPositionId(tokenA, tokenB);
        assertEq(uint256(positionId), uint256(keccak256(abi.encodePacked(tokenA, tokenB))));
    }

    function test_GetAmountOutFromIn() public {
        uint256 amountOut = leveragedAMMExchange.getAmountOutFromIn(tokenA, tokenB, 0, 0);
        assertEq(amountOut, 0);
        amountOut = leveragedAMMExchange.getAmountOutFromIn(tokenA, tokenB, 1000, 0);
        assertEq(amountOut, 0);
        amountOut = leveragedAMMExchange.getAmountOutFromIn(tokenA, tokenB, 0, 6);
        assertEq(amountOut, 0);
        leveragedAMMExchange.createPair(tokenA, tokenB, 10000, 1000);
        amountOut = leveragedAMMExchange.getAmountOutFromIn(tokenA, tokenB, 1000, 6);
        assertEq(amountOut, 375);
    }

    function test_GetAmountInForOut() public {
        uint256 amountOut = leveragedAMMExchange.getAmountInForOut(tokenA, tokenB, 0, 0);
        assertEq(amountOut, 0);
        amountOut = leveragedAMMExchange.getAmountInForOut(tokenA, tokenB, 1000, 0);
        assertEq(amountOut, 0);
        amountOut = leveragedAMMExchange.getAmountInForOut(tokenA, tokenB, 0, 6);
        assertEq(amountOut, 0);
        leveragedAMMExchange.createPair(tokenA, tokenB, 10000, 1000);
        amountOut = leveragedAMMExchange.getAmountInForOut(tokenA, tokenB, 375, 6);
        assertEq(amountOut, 1000);
        amountOut = leveragedAMMExchange.getAmountInForOut(tokenA, tokenB, 375, 0);
        assertEq(amountOut, 0);
    }

    function test_GetAmountCollateralReturn() public {
        (uint256 leveragedAmount, uint256 collateralAmount) =
            leveragedAMMExchange.getAmountCollateralReturn(tokenA, tokenB, 1000, 0);
        assertEq(collateralAmount, 0);
        assertEq(leveragedAmount, 0);
        (leveragedAmount, collateralAmount) = leveragedAMMExchange.getAmountCollateralReturn(tokenA, tokenB, 0, 6);
        assertEq(collateralAmount, 0);
        assertEq(leveragedAmount, 0);
        (leveragedAmount, collateralAmount) = leveragedAMMExchange.getAmountCollateralReturn(tokenA, tokenB, 0, 0);
        assertEq(collateralAmount, 0);
        assertEq(leveragedAmount, 0);
        leveragedAMMExchange.createPair(tokenA, tokenB, 16000, 625);
        (leveragedAmount, collateralAmount) = leveragedAMMExchange.getAmountCollateralReturn(tokenA, tokenB, 375, 6);
        assertEq(collateralAmount, 1000);
        assertEq(leveragedAmount, 1000 * 6);
        (leveragedAmount, collateralAmount) = leveragedAMMExchange.getAmountCollateralReturn(tokenA, tokenB, 375, 0);
        assertEq(collateralAmount, 0);
        assertEq(leveragedAmount, 0);
    }

    function test_GetAccountRemainingValue() public {
        leveragedAMMExchange.createPair(tokenA, tokenB, 10000, 1000);
        IERC20(tokenA).approve(address(leveragedAMMExchange), 2000);
        leveragedAMMExchange.deposit(tokenA, 2000);
        assertEq(leveragedAMMExchange.getAccountRemainingValue(address(this), tokenA, tokenB), 2000 * maxLeverage);
    }

    function test_Swap_Open_CrossMode() public {
        uint256 reserveA = 100000;
        uint256 reserveB = 10000;
        uint256 depositAmount = 20000;
        uint256 amountIn = 10000;
        uint8 leverage = leveragedAMMExchange.MAX_LEVERAGE();

        leveragedAMMExchange.createPair(tokenA, tokenB, reserveA, reserveB);
        IERC20(tokenA).approve(address(leveragedAMMExchange), depositAmount);
        leveragedAMMExchange.deposit(tokenA, depositAmount);

        // Case 1: Open position
        uint256 amountOut = leveragedAMMExchange.getAmountOutFromIn(tokenA, tokenB, amountIn, leverage);
        leveragedAMMExchange.swap(
            ILeveragedAMMExchange.Order({
                tokenA: tokenA,
                tokenB: tokenB,
                amount: amountIn,
                leverage: leverage,
                positionMode: ILeveragedAMMExchange.Mode.CROSS,
                reducePosition: false,
                closePosition: false,
                closePosIndex: 0
            })
        );

        // Check reserves and balances
        (, uint256 reserveA_, uint256 reserveB_) = leveragedAMMExchange.pairs(tokenA, tokenB);
        assertEq(reserveA_, reserveA + amountIn * leverage);
        assertEq(reserveB_, reserveB - amountOut);
        uint256 balance_ = leveragedAMMExchange.balances(address(this), tokenA);
        assertEq(balance_, depositAmount - amountIn);

        // Check remaining value and position worth value
        uint256 remainingValue = depositAmount * maxLeverage - amountIn * leverage;
        assertEq(leveragedAMMExchange.getAccountRemainingValue(address(this), tokenA, tokenB), remainingValue);
        uint256 positionWorthValue = leveragedAMMExchange.getPositionWorthValue(address(this), tokenA, tokenB);
        assertEq(positionWorthValue, amountIn * leverage);

        // Check position information
        ILeveragedAMMExchange.Position memory position =
            leveragedAMMExchange.getPositionCross(address(this), tokenA, tokenB);
        assertEq(position.tradingPairSymbol, tradingPairSymbol);
        assertEq(position.collateralAmount, amountIn);
        assertEq(position.collateralWorthValue, amountIn * leverage);
        assertEq(position.positionValue, amountOut);
        assertEq(position.leverage, maxLeverage);
    }

    function test_Swap_Reduce_CrossMode() public {
        uint256 reserveA = 100000;
        uint256 reserveB = 10000;
        uint256 depositAmount = 20000;
        uint256 amountIn = 10000;
        uint8 leverage = leveragedAMMExchange.MAX_LEVERAGE();

        leveragedAMMExchange.createPair(tokenA, tokenB, reserveA, reserveB);
        IERC20(tokenA).approve(address(leveragedAMMExchange), depositAmount);
        leveragedAMMExchange.deposit(tokenA, depositAmount);

        // Open position first for testing
        uint256 amountOut = leveragedAMMExchange.getAmountOutFromIn(tokenA, tokenB, amountIn, leverage);
        leveragedAMMExchange.swap(
            ILeveragedAMMExchange.Order({
                tokenA: tokenA,
                tokenB: tokenB,
                amount: amountIn,
                leverage: leverage,
                positionMode: ILeveragedAMMExchange.Mode.CROSS,
                reducePosition: false,
                closePosition: false,
                closePosIndex: 0
            })
        );
        (, uint256 reserveA_, uint256 reserveB_) = leveragedAMMExchange.pairs(tokenA, tokenB);

        // Case 2: Reduce position
        uint256 reduceAmount = amountOut;
        (uint256 leveragedAmount, uint256 amountIn_) =
            leveragedAMMExchange.getAmountCollateralReturn(tokenA, tokenB, reduceAmount, leverage);

        leveragedAMMExchange.swap(
            ILeveragedAMMExchange.Order({
                tokenA: tokenA,
                tokenB: tokenB,
                amount: reduceAmount,
                leverage: leverage,
                positionMode: ILeveragedAMMExchange.Mode.CROSS,
                reducePosition: true,
                closePosition: false,
                closePosIndex: 0
            })
        );
        uint256 remaingCollateralAmount = amountIn - amountIn_;

        // Check reserves and balances
        (, uint256 reserveA__, uint256 reserveB__) = leveragedAMMExchange.pairs(tokenA, tokenB);
        assertEq(reserveA__, reserveA_ - leveragedAmount);
        assertEq(reserveB__, reserveB_ + reduceAmount);
        uint256 balance__ = leveragedAMMExchange.balances(address(this), tokenA);
        assertEq(balance__, depositAmount - remaingCollateralAmount);

        // Check remaining value and position worth value
        uint256 remainingValue = depositAmount * maxLeverage - remaingCollateralAmount * leverage;
        assertEq(leveragedAMMExchange.getAccountRemainingValue(address(this), tokenA, tokenB), remainingValue);
        uint256 positionWorthValue = leveragedAMMExchange.getPositionWorthValue(address(this), tokenA, tokenB);
        assertEq(positionWorthValue, remaingCollateralAmount * leverage);

        // Check position information
        ILeveragedAMMExchange.Position memory position =
            leveragedAMMExchange.getPositionCross(address(this), tokenA, tokenB);
        assertEq(position.tradingPairSymbol, tradingPairSymbol);
        assertEq(position.collateralAmount, remaingCollateralAmount);
        assertEq(position.collateralWorthValue, remaingCollateralAmount * leverage);
        assertEq(position.positionValue, amountOut - reduceAmount);
        assertEq(position.leverage, maxLeverage);
    }

    function test_Swap_Failed() public {
        ILeveragedAMMExchange.Order memory invalidOrder = ILeveragedAMMExchange.Order({
            tokenA: address(0),
            tokenB: address(0),
            amount: 1000,
            leverage: 0,
            positionMode: ILeveragedAMMExchange.Mode.CROSS,
            reducePosition: false,
            closePosition: false,
            closePosIndex: 0
        });
        vm.expectRevert(ILeveragedAMMExchange.InvalidLeverage.selector);
        leveragedAMMExchange.swap(invalidOrder);
        invalidOrder.leverage = 2;
        vm.expectRevert(ILeveragedAMMExchange.InvalidTokenAddress.selector);
        leveragedAMMExchange.swap(invalidOrder);
        invalidOrder.tokenA = tokenA;
        vm.expectRevert(ILeveragedAMMExchange.InvalidTokenAddress.selector);
        leveragedAMMExchange.swap(invalidOrder);
        invalidOrder.tokenB = tokenB;
        IERC20(tokenA).approve(address(leveragedAMMExchange), 10);
        leveragedAMMExchange.deposit(tokenA, 10);
        vm.expectRevert(abi.encodeWithSelector(ILeveragedAMMExchange.InsufficientAmount.selector, 10));
        leveragedAMMExchange.swap(invalidOrder);
    }

    function printAggregatedCrossInfo(string memory tag) public view {
        (string memory pairSymbol, uint256 reserveA, uint256 reserveB) = leveragedAMMExchange.pairs(tokenA, tokenB);
        uint256 price = leveragedAMMExchange.getPairPrice(tokenA, tokenB);
        uint256 depositBalance = leveragedAMMExchange.balances(address(this), tokenA);
        bytes32 positionId = leveragedAMMExchange.getPositionId(tokenA, tokenB);
        (,, uint256 collateralWorthValue, uint256 positionValue,) =
            leveragedAMMExchange.positionCross(address(this), positionId);
        uint256 remainingValue = leveragedAMMExchange.getAccountRemainingValue(address(this), tokenA, tokenB);

        console.log("----------------", tag, "---------------");
        console.log("Pair Symbol:", pairSymbol);
        console.log("Reserves:", reserveA, reserveB);
        console.log("Price (decimals = 6):", price);
        console.log("Deposit & Max Leverage:", depositBalance, maxLeverage);
        console.log("Cross Position:", collateralWorthValue, positionValue, remainingValue);
    }
}
