import fs from 'node:fs'
import url from 'node:url'
import path from 'node:path'
import { defineConfig, type Plugin } from '@wagmi/cli'
import { foundry, etherscan, actions, react, type FoundryConfig } from '@wagmi/cli/plugins'

const __dirname = path.dirname(url.fileURLToPath(import.meta.url))

const ENABLE_ETHERSCAN = true

/**
 * docs: https://beta.wagmi.sh
 * Runs forge build then generates a single typescript file containing all ABIs
 * Usage:
 * ```sh
 * bun wagmi generate path/to/write/to.ts
 * ```
 */

const [, outDir] = process.argv.slice(2)

export default defineConfig([
  {
    out: outDir ? path.join(outDir, 'abi.ts') : path.join(__dirname, 'generated', 'abi.ts'),
    plugins: [
      foundryPlugin({
        build: true,
        clean: true,
        rebuild: true
      }),
      etherscanPlugin()
    ]
  },
  {
    out: outDir ? path.join(outDir, 'actions.ts') : path.join(__dirname, 'generated', 'actions.ts'),
    plugins: [foundryPlugin(), actions()]
  },
  {
    out: outDir ? path.join(outDir, 'react.ts') : path.join(__dirname, 'generated', 'hooks.ts'),
    plugins: [foundryPlugin(), react()]
  }
])

function foundryPlugin(forgeConfig?: FoundryConfig['forge']): Plugin {
  const artifacts = fs
    .readdirSync(path.join(__dirname, 'src'))
    .filter((item) => item.startsWith('EFP'))
    .map((item) => `${item}/**`)

  return foundry({
    artifacts: 'out/',
    include: artifacts,
    project: __dirname,
    forge: { build: true, clean: false, rebuild: false, ...forgeConfig }
  })
}

/**
 * Only Sepolia for now
 */
function etherscanPlugin(): Plugin {
  if (!ENABLE_ETHERSCAN) {
    return () => {}
  }
  return etherscan({
    apiKey: process.env.ETHERSCAN_API_KEY,
    chainId: 84532,
    contracts: [
    //   {
    //     name: 'EFPAccountMetadata',
    //     address: '0x5289fE5daBC021D02FDDf23d4a4DF96F4E0F17EF'
    //   },
    //   {
    //     name: 'EFPListRecords',
    //     address: '0x41Aa48Ef3c0446b46a5b1cc6337FF3d3716E2A33'
    //   },
    //   {
    //     name: 'EFPListRegistry',
    //     address: '0x0E688f5DCa4a0a4729946ACbC44C792341714e08'
    //   },
      {
        name: 'EFPListRecordsV2',
        address: '0x933a1bB6697Ae3c30Dd63A863d22763B4E40199A'
      }

    ]
  })
}
