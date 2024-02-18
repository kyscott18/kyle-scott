import {
	http,
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

export const publicClient = createPublicClient({
	chain: foundry,
	transport: http(),
});

export const walletClient = createWalletClient({
	chain: foundry,
	transport: http(),
	account: ALICE,
});

export const mockErc20Abi = parseAbi([
	"constructor(string _name, string  _symbol, uint8 _decimals)",
	"function approve(address spender, uint256 amount)",
	"function transfer(address to, uint256 amount)",
	"function transferFrom(address from, address to, uint256 amount)",
	"function mint(address to, uint256 amount)",
	"function burn(address from, uint256 amount)",
]);

export const deployErc20 = () =>
	walletClient.deployContract({
		account: ALICE,
		abi: mockErc20Abi,
		bytecode: MockERC20Bytecode.bytecode.object as Hex,
		args: ["name", "symbol", 18],
	});
