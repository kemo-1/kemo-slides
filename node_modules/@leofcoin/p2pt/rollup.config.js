// import modify from 'rollup-plugin-modify';
import typescript from '@rollup/plugin-typescript'
import commonjs from '@rollup/plugin-commonjs'
// import json from '@rollup/plugin-json';
import rimraf from 'rimraf'
import nodeResolve from '@rollup/plugin-node-resolve'
// import tsconfig from './tsconfig.json' assert { type: 'json'};
import { execSync } from 'child_process'
import { join } from 'path'
try {
  rimraf.sync('./exports/**/*')
  execSync(`mkdir ${join('exports', 'browser')}`)
} catch (e) {
  console.log('nothing to clean')
}

export default [
  {
    input: ['src/p2pt.ts', 'src/node.ts'],
    output: [
      {
        dir: './exports/commonjs',
        format: 'cjs'
      }
    ],
    external: [
      'debug',
      'simple-sha1',
      'bittorrent-tracker/lib/client/websocket-tracker.js',
      'simple-websocket',
      '@koush/wrtc',
      'wrtc.node'
    ],
    plugins: [
      // commonjs({exclude: ['./simple-peer.js']}),
      nodeResolve({ preferBuiltins: true }),
      typescript({ compilerOptions: { declaration: false } })
    ]
  },
  {
    input: ['src/p2pt.ts', 'src/node.ts'],
    output: [
      {
        dir: './exports',
        format: 'es'
      }
    ],
    external: ['bittorrent-tracker/lib/client/websocket-tracker', 'simple-websocket', '@koush/wrtc', 'wrtc.node'],
    plugins: [typescript({ compilerOptions: { declarationDir: './exports' } })]
  }
]
