import { startProxy } from "@viem/anvil";
import {
	Q128,
	addLiquidity,
	approveLiquidity,
	deployEngine,
	deployRouter,
	removeLiquidity,
	swap,
} from "./ks";
import { ALICE, BOB, approveErc20, deployErc20, mintErc20 } from "./utils";

const shutdown = await startProxy();

const tokenA = await deployErc20();
const tokenB = await deployErc20();

const token0 = tokenA.toLowerCase() < tokenB.toLowerCase() ? tokenA : tokenB;
const token1 = tokenA.toLowerCase() < tokenB.toLowerCase() ? tokenB : tokenA;

await mintErc20(token0, ALICE, 10n ** 19n);
await mintErc20(token1, ALICE, 10n ** 19n);
await mintErc20(token0, BOB, 10n ** 19n);
await mintErc20(token1, BOB, 10n ** 19n);

const engine = await deployEngine();
const router = await deployRouter(engine);

await mintErc20(token1, engine, 1n);

await approveErc20(token0, ALICE, router, 10n ** 19n);
await approveErc20(token1, ALICE, router, 10n ** 19n);
await approveErc20(token0, BOB, router, 10n ** 19n);
await approveErc20(token1, BOB, router, 10n ** 19n);

await addLiquidity({
	router,
	token0,
	token1,
	account: BOB,
	ratio: Q128,
	amountBefore: 0n,
	amountAfter: 10n ** 18n,
});

const addLiquidityColdReceipt = await addLiquidity({
	router,
	token0,
	token1,
	account: ALICE,
	ratio: Q128,
	amountBefore: 10n ** 18n,
	amountAfter: 2n * 10n ** 18n,
});

const addLiquidityHotReceipt = await addLiquidity({
	router,
	token0,
	token1,
	account: ALICE,
	ratio: Q128,
	amountBefore: 2n * 10n ** 18n,
	amountAfter: 3n * 10n ** 18n,
});

console.log("Add liquidity (cold):", addLiquidityColdReceipt.gasUsed);
console.log("Add liquidity (hot):", addLiquidityHotReceipt.gasUsed);

await approveLiquidity({
	account: ALICE,
	engine,
	router,
});

const removeLiquidityReceipt = await removeLiquidity({
	router,
	token0,
	token1,
	account: ALICE,
	ratio: Q128,
	amountBefore: 3n * 10n ** 18n,
	amountAfter: 2n * 10n ** 18n,
});

console.log("Remove liquidity:", removeLiquidityReceipt.gasUsed);

const swapReceipt = await swap({
	router,
	token0,
	token1,
	account: ALICE,
	ratio: Q128,
	amount: 2n * 10n ** 18n,
});

console.log("Swap:", swapReceipt.gasUsed);

await shutdown();
