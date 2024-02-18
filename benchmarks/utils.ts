import {
	http,
	type Address,
	type Chain,
	type Hex,
	createPublicClient,
	createWalletClient,
	parseAbi,
} from "viem";
import { foundry } from "viem/chains";
import MockERC20Bytecode from "../out/MockERC20.sol/MockERC20.json";

// Test accounts
export const ACCOUNTS = [
	"0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
	"0x70997970C51812dc3A010C7d01b50e0d17dc79C8",
] as const;

// Named accounts
export const [ALICE, BOB] = ACCOUNTS;

const anvil = {
	...foundry, // We are using a mainnet fork for testing.
	rpcUrls: {
		// These rpc urls are automatically used in the transports.
		default: {
			// Note how we append the worker id to the local rpc urls.
			http: ["http://127.0.0.1:8545/1"],
			webSocket: ["ws://127.0.0.1:8545/1"],
		},
		public: {
			// Note how we append the worker id to the local rpc urls.
			http: ["http://127.0.0.1:8545/1"],
			webSocket: ["ws://127.0.0.1:8545/1"],
		},
	},
} as const satisfies Chain;

export const publicClient = createPublicClient({
	chain: anvil,
	transport: http(),
});

export const walletClient = createWalletClient({
	chain: anvil,
	transport: http(),
	account: ALICE,
});

export const mockErc20Abi = parseAbi([
	"function approve(address spender, uint256 amount) returns (bool)",
	"function allowance(address owner, address spender) returns (uint256)",
	"function balanceOf(address) returns (uint256)",
	"function mint(address to, uint256 amount)",
	"function burn(address from, uint256 amount)",
]);

export const deployErc20 = async () => {
	const hash = await walletClient.deployContract({
		abi: mockErc20Abi,
		bytecode: MockERC20Bytecode.bytecode.object as Hex,
	});

	const receipt = await publicClient.waitForTransactionReceipt({ hash });

	if (!receipt.contractAddress) throw Error("No contract address in receipt");

	return receipt.contractAddress;
};

export const mintErc20 = async (
	token: Address,
	to: Address,
	amount: bigint,
) => {
	const hash = await walletClient.writeContract({
		abi: mockErc20Abi,
		functionName: "mint",
		address: token,
		args: [to, amount],
	});

	await publicClient.waitForTransactionReceipt({ hash });
};

export const approveErc20 = async (
	token: Address,
	owner: Address,
	spender: Address,
	amount: bigint,
) => {
	const hash = await walletClient.writeContract({
		account: owner,
		abi: mockErc20Abi,
		functionName: "approve",
		address: token,
		args: [spender, amount],
	});

	await publicClient.waitForTransactionReceipt({ hash });
};
