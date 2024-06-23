// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import {MyToken} from "../src/tests/MyToken.sol";
import {LeveragedAMMExchangeCrossMode} from "../src/LeveragedAMMExchangeCrossMode.sol";
import {LeveragedAMMExchangeIsolatedMode} from "../src/LeveragedAMMExchangeIsolatedMode.sol";

contract LeveragedAMMExchangeDeployment is Script {
    function run()
        external
        returns (MyToken, MyToken, MyToken, MyToken, LeveragedAMMExchangeCrossMode, LeveragedAMMExchangeIsolatedMode)
    {
        vm.startBroadcast();
        uint8 decimals = 18;
        uint256 MUL = 10 ** decimals;
        MyToken daiToken = new MyToken("Dai Stablecoin", "DAI", decimals, 1000000 * MUL);
        MyToken wethToken = new MyToken("Wrapped ETH", "WETH", decimals, 1000000 * MUL);
        MyToken bnbToken = new MyToken("Binance Coin", "BNB", decimals, 1000000 * MUL);
        MyToken perpToken = new MyToken("Perpetual", "PERP", decimals, 1000000 * MUL);
        LeveragedAMMExchangeCrossMode leveragedAMMExchangeCrossMode = new LeveragedAMMExchangeCrossMode();
        LeveragedAMMExchangeIsolatedMode leveragedAMMExchangeIsolatedMode = new LeveragedAMMExchangeIsolatedMode();
        leveragedAMMExchangeCrossMode.createPair(address(daiToken), address(wethToken), 10000 * MUL, 1000 * MUL);
        leveragedAMMExchangeCrossMode.createPair(address(daiToken), address(bnbToken), 20000 * MUL, 4000 * MUL);
        leveragedAMMExchangeCrossMode.createPair(address(daiToken), address(perpToken), 30000 * MUL, 6000 * MUL);
        leveragedAMMExchangeIsolatedMode.createPair(address(daiToken), address(wethToken), 10000 * MUL, 1000 * MUL);
        leveragedAMMExchangeIsolatedMode.createPair(address(daiToken), address(bnbToken), 20000 * MUL, 4000 * MUL);
        leveragedAMMExchangeIsolatedMode.createPair(address(daiToken), address(perpToken), 30000 * MUL, 6000 * MUL);
        vm.stopBroadcast();

        return
            (daiToken, wethToken, bnbToken, perpToken, leveragedAMMExchangeCrossMode, leveragedAMMExchangeIsolatedMode);
    }
}
