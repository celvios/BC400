# FRONTEND_PROMPT.md
## Multi-Chain Token Portal — Frontend Build Prompt (Phase 6)

---

## 📌 Before You Begin

1. Read `PERSONALITY.md` — all behavioral rules apply here too
2. This is a **production frontend** — real users, real funds, real transactions
3. Re-read this file at the start of every frontend session
4. Design and engineering are equally important here — both must be exceptional

---

## 🎨 Design Identity

### Visual Language: **Dark Glassmorphism**

This portal is the face of a serious multi-chain DeFi product. It must feel:
- **Premium** — like a product that handles real money
- **Trustworthy** — clean, minimal, never overwhelming
- **Futuristic** — subtle depth, light, and glass — not cartoonish
- **Calm** — no aggressive colors, no busy layouts, no anxiety-inducing UI

### Aesthetic Direction

**Glassmorphism + Minimalism** — every element breathes.

```
Background:   Deep space dark — near-black with very subtle blue/purple undertone
              Animated gradient mesh slowly drifting (CSS only, performant)
              Faint grain/noise overlay for texture depth

Glass panels: backdrop-filter: blur(20px) saturate(180%)
              background: rgba(255, 255, 255, 0.04)
              border: 1px solid rgba(255, 255, 255, 0.08)
              box-shadow: 0 8px 32px rgba(0, 0, 0, 0.4),
                          inset 0 1px 0 rgba(255, 255, 255, 0.1)

Accent color: Single cool accent — ice blue or cyan-white
              Used sparingly: CTAs, active states, highlights only
              Never used for backgrounds

Text:         Primary: rgba(255, 255, 255, 0.92)
              Secondary: rgba(255, 255, 255, 0.45)
              Muted: rgba(255, 255, 255, 0.25)
```

### Typography

- **Display / Headings:** `Syne` (Google Fonts) — geometric, modern, slightly unusual
- **Body / UI:** `DM Sans` (Google Fonts) — clean, readable, distinct from Inter
- **Monospace / Addresses:** `JetBrains Mono` — for wallet addresses, tx hashes, numbers
- Never use: Inter, Roboto, Arial, system-ui

### CSS Design Tokens (required — no hardcoded values in components)

```css
:root {
  /* Backgrounds */
  --bg-base:           #080b14;
  --bg-mesh-1:         #0d1528;
  --bg-mesh-2:         #0a0f1e;

  /* Glass */
  --glass-bg:          rgba(255, 255, 255, 0.04);
  --glass-bg-hover:    rgba(255, 255, 255, 0.07);
  --glass-bg-active:   rgba(255, 255, 255, 0.10);
  --glass-border:      rgba(255, 255, 255, 0.08);
  --glass-border-hover:rgba(255, 255, 255, 0.16);
  --glass-blur:        blur(20px) saturate(180%);
  --glass-shadow:      0 8px 32px rgba(0, 0, 0, 0.4), inset 0 1px 0 rgba(255, 255, 255, 0.08);

  /* Accent */
  --accent:            #7eb8f7;
  --accent-bright:     #a8d4ff;
  --accent-dim:        rgba(126, 184, 247, 0.15);
  --accent-glow:       0 0 20px rgba(126, 184, 247, 0.3);

  /* Text */
  --text-primary:      rgba(255, 255, 255, 0.92);
  --text-secondary:    rgba(255, 255, 255, 0.50);
  --text-muted:        rgba(255, 255, 255, 0.25);
  --text-accent:       var(--accent);

  /* Status */
  --success:           #4ade80;
  --success-dim:       rgba(74, 222, 128, 0.12);
  --warning:           #fbbf24;
  --warning-dim:       rgba(251, 191, 36, 0.12);
  --error:             #f87171;
  --error-dim:         rgba(248, 113, 113, 0.12);

  /* Spacing scale */
  --space-1: 4px;
  --space-2: 8px;
  --space-3: 12px;
  --space-4: 16px;
  --space-6: 24px;
  --space-8: 32px;
  --space-12: 48px;
  --space-16: 64px;

  /* Radius */
  --radius-sm:  8px;
  --radius-md:  12px;
  --radius-lg:  16px;
  --radius-xl:  24px;
  --radius-full: 9999px;

  /* Transitions */
  --transition-fast:   150ms cubic-bezier(0.4, 0, 0.2, 1);
  --transition-base:   250ms cubic-bezier(0.4, 0, 0.2, 1);
  --transition-slow:   400ms cubic-bezier(0.4, 0, 0.2, 1);
}
```

---

## 🏗️ Tech Stack

```
Framework:        Next.js 14 (App Router)
Language:         TypeScript — strict mode, zero any types
Styling:          Tailwind CSS + CSS variables (tokens above)
Wallet:           RainbowKit v2 + wagmi v2
Chain library:    viem
Components:       shadcn/ui (customized to match glass theme)
Fonts:            next/font (Google Fonts — Syne, DM Sans, JetBrains Mono)
Animations:       CSS transitions + keyframes (no heavy animation libraries)
Icons:            lucide-react
```

---

## 📁 Frontend Structure

```
frontend/
├── src/
│   ├── app/
│   │   ├── layout.tsx              ← Root layout, fonts, providers
│   │   ├── page.tsx                ← Migration page (/)
│   │   ├── bridge/
│   │   │   └── page.tsx            ← Bridge page (/bridge)
│   │   ├── dashboard/
│   │   │   └── page.tsx            ← Dashboard (/dashboard)
│   │   └── globals.css             ← CSS tokens + base styles + animations
│   │
│   ├── components/
│   │   ├── layout/
│   │   │   ├── Navbar.tsx          ← Top nav: logo, chain indicator, wallet button
│   │   │   └── Background.tsx      ← Animated mesh gradient background
│   │   ├── glass/
│   │   │   ├── GlassCard.tsx       ← Reusable glass panel component
│   │   │   ├── GlassButton.tsx     ← Primary, secondary, ghost variants
│   │   │   ├── GlassInput.tsx      ← Token amount input
│   │   │   └── GlassBadge.tsx      ← Chain badges, status badges
│   │   ├── migrate/
│   │   │   ├── MigrateCard.tsx     ← Main migration UI card
│   │   │   ├── BalanceDisplay.tsx  ← Old + new token balance
│   │   │   ├── MigrateSteps.tsx    ← Approve → Migrate step indicator
│   │   │   └── Countdown.tsx       ← Migration deadline countdown
│   │   ├── bridge/
│   │   │   ├── BridgeCard.tsx      ← Main bridge UI card
│   │   │   ├── ChainSelector.tsx   ← Source/destination chain picker
│   │   │   ├── FeeEstimate.tsx     ← LayerZero fee display
│   │   │   └── BridgeStatus.tsx    ← Pending/complete status
│   │   ├── dashboard/
│   │   │   ├── BalanceGrid.tsx     ← Token balance across chains
│   │   │   ├── MigrationProgress.tsx ← % migrated progress bar
│   │   │   └── StatCard.tsx        ← Individual stat display
│   │   └── shared/
│   │       ├── TxHash.tsx          ← Formatted tx hash with explorer link
│   │       ├── AddressDisplay.tsx  ← Truncated address with copy button
│   │       ├── TokenAmount.tsx     ← Formatted token amount
│   │       ├── ChainIcon.tsx       ← Chain logo/icon component
│   │       ├── LoadingSkeleton.tsx ← Glass skeleton loader
│   │       └── ErrorState.tsx      ← Error display component
│   │
│   ├── hooks/
│   │   ├── useTokenBalance.ts      ← Balance on any chain
│   │   ├── useMigrate.ts           ← Migration flow state machine
│   │   ├── useApproval.ts          ← ERC20 approval flow
│   │   ├── useBridge.ts            ← Bridge flow state machine
│   │   ├── useBridgeFee.ts         ← quoteSend fee estimation
│   │   ├── useMigrationStatus.ts   ← Deadline, active state, progress
│   │   └── useChainBalances.ts     ← All chain balances in parallel
│   │
│   ├── config/
│   │   ├── chains.ts               ← wagmi chain configs (from env)
│   │   ├── contracts.ts            ← Contract addresses per chain (from env)
│   │   ├── wagmi.ts                ← wagmi + RainbowKit setup
│   │   └── abis/
│   │       ├── token.abi.ts
│   │       └── migration.abi.ts
│   │
│   ├── lib/
│   │   ├── env.ts                  ← Env validation (throws on missing)
│   │   ├── format.ts               ← Number, address, token formatters
│   │   └── errors.ts               ← Contract error parsing
│   │
│   └── types/
│       ├── chains.ts
│       └── contracts.ts
│
├── public/
│   └── chains/                     ← Chain logos (BSC, ETH, Base, Sonic, Polygon)
│
├── .env.example
├── tailwind.config.ts
├── next.config.ts
└── tsconfig.json                   ← strict: true
```

---

## 🎨 Component Design Specifications

### Background (`Background.tsx`)

```css
/* Animated gradient mesh — CSS only, no JS */
.bg-mesh {
  position: fixed;
  inset: 0;
  background: var(--bg-base);
  z-index: 0;
}

.bg-mesh::before {
  content: '';
  position: absolute;
  inset: 0;
  background:
    radial-gradient(ellipse 80% 60% at 20% 40%, rgba(59, 130, 246, 0.08) 0%, transparent 60%),
    radial-gradient(ellipse 60% 80% at 80% 20%, rgba(99, 102, 241, 0.06) 0%, transparent 60%),
    radial-gradient(ellipse 40% 40% at 60% 80%, rgba(14, 165, 233, 0.05) 0%, transparent 60%);
  animation: meshDrift 20s ease-in-out infinite alternate;
}

.bg-mesh::after {
  content: '';
  position: absolute;
  inset: 0;
  background-image: url("data:image/svg+xml,..."); /* noise SVG */
  opacity: 0.025;
}

@keyframes meshDrift {
  0%   { transform: translate(0, 0) scale(1); }
  100% { transform: translate(20px, -20px) scale(1.05); }
}
```

### GlassCard (`GlassCard.tsx`)

```tsx
// Variants: default, elevated, subtle
// Sizes: sm, md, lg
// Props: variant, size, className, children, onClick (optional — adds hover)

// Default glass card CSS:
.glass-card {
  background: var(--glass-bg);
  backdrop-filter: var(--glass-blur);
  -webkit-backdrop-filter: var(--glass-blur);
  border: 1px solid var(--glass-border);
  border-radius: var(--radius-xl);
  box-shadow: var(--glass-shadow);
  transition: all var(--transition-base);
}

.glass-card:hover {
  background: var(--glass-bg-hover);
  border-color: var(--glass-border-hover);
}

// Elevated variant adds extra glow:
.glass-card-elevated {
  box-shadow: var(--glass-shadow), 0 0 60px rgba(126, 184, 247, 0.05);
}
```

### GlassButton (`GlassButton.tsx`)

```
Variants:
  primary  → accent background, bright text, glow on hover
  secondary → glass bg, accent border, accent text
  ghost    → transparent, muted text, glass bg on hover
  danger   → error color scheme

States:
  default, hover, active, loading (spinner), disabled

Loading state:
  - Show spinner (CSS animated)
  - Keep button width (no layout shift)
  - Show "Confirming..." or relevant text

Never:
  - Disable button without tooltip explaining why
  - Show empty loading button with no context
```

### GlassInput (`GlassInput.tsx`)

```
- Token amount input (numeric only)
- Right side: token symbol badge + "Max" button
- Below: USD value estimate (if price available)
- States: default, focused (accent border glow), error (red border + message)
- Never allow: negative values, more decimals than token allows
- Format large numbers with commas as user types
```

### ChainSelector (`ChainSelector.tsx`)

```
- Dropdown showing all 5 chains
- Each option: chain icon + chain name + current balance
- Active chain: accent highlight
- Disabled option: if same as opposite selector
- Smooth open/close animation
```

---

## 📄 Page Specifications

### Page 1: Migration (`/`)

**Layout:** Single centered card, max-width 480px, vertically centered on desktop

**Header:**
- Token name + logo (small)
- "Token Migration" subtitle
- Countdown timer: `XX days XX hrs XX mins` until deadline
- If deadline passed: red "Migration Closed" badge

**Main Card:**
```
┌─────────────────────────────────────┐
│  Your Balances                       │
│                                      │
│  OLD TOKEN    [amount]  [symbol]     │
│  ──────────────────────────────────  │
│  NEW TOKEN    [amount]  [symbol]     │
│                                      │
│  ──────────────────────────────────  │
│                                      │
│  Amount to migrate                   │
│  [         input          ] [MAX]    │
│                                      │
│  ──────────────────────────────────  │
│                                      │
│  Step 1 of 2                         │
│  ● Approve  ○ Migrate                │
│                                      │
│  [    Approve Token Transfer    ]    │
│                                      │
│  Est. gas: ~$0.12                    │
└─────────────────────────────────────┘
```

**Full State Machine:**

```typescript
type MigrationState =
  | 'idle'                    // No wallet connected
  | 'wrong_network'           // Connected but not on BSC
  | 'loading_balances'        // Fetching balances
  | 'no_old_tokens'           // Wallet has 0 old tokens
  | 'deadline_passed'         // Migration window closed
  | 'ready'                   // Ready to migrate
  | 'approving'               // Approval tx pending
  | 'approval_failed'         // Approval tx failed
  | 'approved'                // Approval confirmed, ready to migrate
  | 'migrating'               // Migration tx pending
  | 'migration_failed'        // Migration tx failed
  | 'success'                 // Migration complete
```

Each state renders a distinct UI — no generic "something went wrong" messages.

**Success State:**
- Green glow on card
- Checkmark animation
- New token balance displayed
- "Add to wallet" button (adds new token to MetaMask)
- "View on BscScan" link

---

### Page 2: Bridge (`/bridge`)

**Layout:** Single centered card, max-width 520px

**Main Card:**
```
┌─────────────────────────────────────┐
│  Bridge Tokens                       │
│                                      │
│  FROM                                │
│  [chain selector ▾]    Balance: 0.0  │
│  [      amount input       ] [MAX]   │
│                                      │
│  ↕ (swap button)                     │
│                                      │
│  TO                                  │
│  [chain selector ▾]    Balance: 0.0  │
│                                      │
│  ──────────────────────────────────  │
│  Bridge Fee        ~0.0012 ETH       │
│  Est. Time         1–5 minutes       │
│  You Receive       [amount] TOKEN    │
│  ──────────────────────────────────  │
│                                      │
│  [        Bridge Tokens         ]    │
└─────────────────────────────────────┘
```

**State Machine:**
```typescript
type BridgeState =
  | 'idle'
  | 'wrong_network'
  | 'loading_fee'
  | 'fee_error'
  | 'ready'
  | 'insufficient_balance'
  | 'insufficient_gas'
  | 'bridging'
  | 'bridge_failed'
  | 'success'
```

**Bridge Pending State:**
- Card shows animated status
- Source chain: "Sent ✓" with tx hash
- Destination chain: pulsing "Waiting for arrival..."
- Auto-updates when destination confirms (poll or event)
- Estimated time countdown

---

### Page 3: Dashboard (`/dashboard`)

**Layout:** Grid layout — wider than other pages, max-width 900px

**Top Stats Row (3 glass cards):**
```
[Total Supply]    [Migrated %]    [Chains Active]
```

**Balance Grid (5 cards, one per chain):**
```
┌──────────┐  ┌──────────┐  ┌──────────┐
│  🔶 BSC  │  │  ◆ ETH   │  │  🔵 Base │
│ 0.00 TKN │  │ 0.00 TKN │  │ 0.00 TKN │
│ $0.00    │  │ $0.00    │  │ $0.00    │
└──────────┘  └──────────┘  └──────────┘
```

**Migration Progress:**
```
Old tokens migrated
████████████░░░░  68.4%
6,840,000 / 10,000,000 tokens
```

**Links Section:**
- PancakeSwap LP link
- Block explorer links (all 5)
- Contract address display per chain (copyable, truncated)

---

## 🔗 Navbar (`Navbar.tsx`)

```
[LOGO + TOKEN NAME]          [Migrate] [Bridge] [Dashboard]    [Connect Wallet]
```

- Glassmorphism background with blur
- Sticky at top
- Active page: accent underline
- Mobile: hamburger menu with slide-in drawer (glass panel)
- Wallet button: shows truncated address when connected, chain indicator dot
- Chain indicator: colored dot matching current chain color

---

## 🪝 Hook Specifications

### `useMigrate.ts`

```typescript
interface UseMigrateReturn {
  state: MigrationState;
  oldBalance: bigint | undefined;
  newBalance: bigint | undefined;
  allowance: bigint | undefined;
  deadline: Date | undefined;
  isDeadlinePassed: boolean;
  approve: (amount: bigint) => Promise<void>;
  migrate: (amount: bigint) => Promise<void>;
  approvalTxHash: `0x${string}` | undefined;
  migrationTxHash: `0x${string}` | undefined;
  error: string | undefined;
  reset: () => void;
}
```

### `useBridgeFee.ts`

```typescript
interface UseBridgeFeeReturn {
  fee: bigint | undefined;
  feeFormatted: string | undefined;  // e.g. "0.0012 ETH"
  isLoading: boolean;
  error: string | undefined;
  refetch: () => void;
}
// Debounce fee fetching — don't call quoteSend on every keystroke
// Re-fetch every 30 seconds automatically
// Show stale indicator if fee is > 60 seconds old
```

### `useChainBalances.ts`

```typescript
// Fetches token balance on all 5 chains in parallel
// Returns loading state per chain (not a single global loading)
// Gracefully handles RPC failures per chain
interface ChainBalance {
  chainId: number;
  balance: bigint | undefined;
  isLoading: boolean;
  error: string | undefined;
}
```

---

## ⚡ Performance Rules

- Lazy load pages (Next.js does this automatically with app router)
- Background animation must use `will-change: transform` — never animate `background-position`
- Skeleton loaders must match the exact layout they replace (no layout shift)
- Debounce all RPC calls triggered by user input (300ms minimum)
- Never fetch data on every render — use proper caching with wagmi's built-in query layer
- Images (chain logos): use `next/image` with explicit dimensions
- Fonts: use `next/font` with `display: swap`

---

## ♿ Accessibility Rules

- All interactive elements must be keyboard navigable
- Focus rings visible (styled with accent color, not removed)
- Error messages linked to inputs via `aria-describedby`
- Loading states announced via `aria-live`
- Wallet addresses in `<abbr>` or have full address in `title` attribute
- Color contrast: all text meets WCAG AA minimum
- Never rely on color alone to convey state

---

## 📱 Responsive Breakpoints

```
Mobile:   < 640px   — Single column, full-width cards, bottom nav
Tablet:   640–1024px — Centered cards, top nav
Desktop:  > 1024px  — Full layout as specified
```

Mobile-specific:
- Chain selector: bottom sheet instead of dropdown
- Bridge page: stacked layout (FROM on top, TO below)
- Dashboard: 2-column balance grid, scrollable

---

## 🔴 Error Handling — User-Facing Messages

Never show raw contract errors to users. Parse and translate:

```typescript
// lib/errors.ts
const ERROR_MESSAGES: Record<string, string> = {
  'MigrationNotActive':          'Migration is currently paused.',
  'MigrationDeadlinePassed':     'The migration window has closed.',
  'InsufficientNewTokenBalance': 'Migration pool is empty. Contact the team.',
  'ZeroAmount':                  'Please enter an amount greater than 0.',
  'user rejected transaction':   'Transaction cancelled.',
  'insufficient funds':          'Not enough funds to cover gas fees.',
  // Add all custom contract errors
};

export function parseContractError(error: unknown): string {
  // Parse and return human-readable message
  // Never return raw error objects or stack traces to UI
}
```

---

## ✅ Frontend Quality Gates

Before marking Phase 6 complete:

- [ ] Zero TypeScript errors (`tsc --noEmit`)
- [ ] Zero `any` types
- [ ] All env vars validated at startup
- [ ] All 3 pages work on mobile (test at 375px)
- [ ] All contract interactions handle loading + error + success
- [ ] No hardcoded chain IDs, addresses, or amounts
- [ ] Lighthouse Performance score ≥ 90
- [ ] Fonts loaded correctly (no FOUT)
- [ ] All error states show user-friendly messages (no raw errors)
- [ ] Wallet connection works on BSC, ETH, Base, Sonic, Polygon
- [ ] Bridge fee auto-refreshes every 30s
- [ ] Migration countdown timer is accurate

---

## 🔗 Key References

- RainbowKit Docs: https://www.rainbowkit.com/docs/introduction
- wagmi v2 Docs: https://wagmi.sh
- viem Docs: https://viem.sh
- Next.js 14 App Router: https://nextjs.org/docs/app
- shadcn/ui: https://ui.shadcn.com
- Tailwind CSS: https://tailwindcss.com/docs
- Google Fonts — Syne: https://fonts.google.com/specimen/Syne
- Google Fonts — DM Sans: https://fonts.google.com/specimen/DM+Sans
- Google Fonts — JetBrains Mono: https://fonts.google.com/specimen/JetBrains+Mono

---

## ⚠️ Critical Frontend Warnings

1. **Never hardcode contract addresses** — every address comes from environment variables via `config/contracts.ts`

2. **Never hardcode chain IDs** — use the chain config system. A user on the wrong chain should get a clear "switch network" prompt, not a broken UI

3. **Bridge fee MUST be shown before confirmation** — if `quoteSend` fails, the bridge button must be disabled with an explanation

4. **Migration approval is a two-step process** — never combine approve + migrate into one button click. Users must explicitly confirm each step

5. **Glass blur is expensive on low-end devices** — use `@media (prefers-reduced-motion)` and `@supports (backdrop-filter)` to gracefully degrade for devices that can't handle it

6. **Wallet addresses must never be fully displayed** — always truncate to `0x1234...5678` format in the UI. Full address goes in copy-to-clipboard only

---

*Re-read `PERSONALITY.md` before writing any component.  
Design is not decoration — it is part of the product.*
