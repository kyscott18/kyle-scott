import type { Address, Hex } from "viem";
import EngineBytecode from "../../out/Engine.sol/Engine.json";
import RouterBytecode from "../../out/RouterApprove.sol/RouterApprove.json";
import { engineAbi, routerApproveAbi } from "../generated";
import { publicClient, walletClient } from "../utils";

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
