import { defineConfig } from "@wagmi/cli";
import { foundry } from "@wagmi/cli/plugins";

export default defineConfig({
	out: "benchmarks/generated.ts",
	contracts: [],
	plugins: [
		foundry({
			project: "./",
			include: ["Engine.sol/**", "RouterApprove.sol/**"],
		}),
	],
});
