import { type Address, type Hex, encodeAbiParameters, keccak256 } from "viem";
import EngineBytecode from "../out/Engine.sol/Engine.json";
import RouterBytecode from "../out/RouterApprove.sol/RouterApprove.json";
import { engineAbi, routerApproveAbi } from "./generated";
import { publicClient, walletClient } from "./utils";

export const Q128 = 2n ** 128n;

export const deployEngine = async () => {
	const hash = await walletClient.deployContract({
		abi: engineAbi,
		bytecode: EngineBytecode.bytecode.object as Hex,
	});

	const receipt = await publicClient.waitForTransactionReceipt({ hash });

	if (!receipt.contractAddress) throw Error("No contract address in receipt");

	return receipt.contractAddress;
};

export const deployRouter = async (engine: Address) => {
	const hash = await walletClient.deployContract({
		abi: routerApproveAbi,
		bytecode: RouterBytecode.bytecode.object as Hex,
		args: [engine],
	});

	const receipt = await publicClient.waitForTransactionReceipt({ hash });

	if (!receipt.contractAddress) throw Error("No contract address in receipt");

	return receipt.contractAddress;
};

export const addLiquidity = async ({
	router,
	token0,
	token1,
	account,
	ratio,
	amountBefore,
	amountAfter,
}: {
	router: Address;
	token0: Address;
	token1: Address;
	account: Address;
	ratio: bigint;
	amountBefore: bigint;
	amountAfter: bigint;
}) => {
	const simulate = await publicClient.simulateContract({
		account,
		abi: routerApproveAbi,
		address: router,
		functionName: "route",
		args: [
			[
				{
					token0,
					token1,
					ratio,
					strikeBefore: {
						token: 0,
						amount: amountBefore,
						liquidity: amountBefore,
					},
					strikeAfter: {
						token: 0,
						amount: amountAfter,
						liquidity: amountAfter,
					},
				},
			],
			account,
			[
				{
					token: token0,
					amount: amountAfter - amountBefore,
				},
			],
			[],
		],
	});

	const hash = await walletClient.writeContract(simulate.request);

	return await publicClient.waitForTransactionReceipt({ hash });
};

export const approveLiquidity = async ({
	account,
	engine,
	router,
}: { account: Address; engine: Address; router: Address }) => {
	const simulate = await publicClient.simulateContract({
		account,
		abi: engineAbi,
		functionName: "approve_BKoIou",
		address: engine,
		args: [router, { approved: true }],
	});

	const hash = await walletClient.writeContract(simulate.request);

	await publicClient.waitForTransactionReceipt({ hash });
};

export const removeLiquidity = async ({
	router,
	token0,
	token1,
	account,
	ratio,
	amountBefore,
	amountAfter,
}: {
	router: Address;
	token0: Address;
	token1: Address;
	account: Address;
	ratio: bigint;
	amountBefore: bigint;
	amountAfter: bigint;
}) => {
	const simulate = await publicClient.simulateContract({
		account,
		abi: routerApproveAbi,
		address: router,
		functionName: "route",
		args: [
			[
				{
					token0,
					token1,
					ratio,
					strikeBefore: {
						token: 0,
						amount: amountBefore,
						liquidity: amountBefore,
					},
					strikeAfter: {
						token: 0,
						amount: amountAfter,
						liquidity: amountAfter,
					},
				},
			],
			account,
			[],
			[
				{
					id: keccak256(
						encodeAbiParameters(
							[{ type: "address" }, { type: "address" }, { type: "uint256" }],
							[token0, token1, ratio],
						),
					),
					amount: amountBefore - amountAfter,
				},
			],
		],
	});

	const hash = await walletClient.writeContract(simulate.request);

	return await publicClient.waitForTransactionReceipt({ hash });
};

export const swap = async ({
	router,
	token0,
	token1,
	account,
	ratio,
	amount,
}: {
	router: Address;
	token0: Address;
	token1: Address;
	account: Address;
	ratio: bigint;
	amount: bigint;
}) => {
	const simulate = await publicClient.simulateContract({
		account,
		abi: routerApproveAbi,
		address: router,
		functionName: "route",
		args: [
			[
				{
					token0,
					token1,
					ratio,
					strikeBefore: {
						token: 0,
						amount: amount,
						liquidity: amount,
					},
					strikeAfter: {
						token: 1,
						amount: amount,
						liquidity: amount,
					},
				},
			],
			account,
			[
				{
					token: token1,
					amount,
				},
			],
			[],
		],
	});

	const hash = await walletClient.writeContract(simulate.request);

	return await publicClient.waitForTransactionReceipt({ hash });
};
