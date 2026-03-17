import type { Config } from 'tailwindcss'

const config: Config = {
  content: ['./src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        rarity: {
          common:    '#9ca3af',
          uncommon:  '#22c55e',
          rare:      '#3b82f6',
          epic:      '#a855f7',
          legendary: '#f59e0b',
        },
      },
    },
  },
  plugins: [],
}

export default config
