import { startProxy } from "@viem/anvil";
import { parseEther } from "viem/utils";
import { ALICE, deployErc20, mintErc20, publicClient } from "./utils";

const shutdown = await startProxy();

const tokenA = await deployErc20();
const tokenB = await deployErc20();

await mintErc20(tokenA, ALICE, parseEther("10"));
await mintErc20(tokenB, ALICE, parseEther("10"));

console.log({ tokenA, tokenB });

await shutdown();
