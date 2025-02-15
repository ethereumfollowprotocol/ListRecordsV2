declare namespace NodeJS {
	interface ProcessEnv {
		readonly NODE_ENV: "development" | "production" | "test";
		readonly PRIVATE_KEY: string;
		readonly ETH_RPC_URL: string;
		readonly ETHERSCAN_API_KEY: string;
	}
}