'use client';

import { useAccount, useReadContract } from 'wagmi';
import { formatTokenAmount } from '@/lib/format';
import { TOKEN_ABI } from '@/config/abis/token.abi';
import { MIGRATION_ABI } from '@/config/abis/migration.abi';
import { CONTRACTS, CHAIN_INFO, TOKEN_SYMBOL, SUPPORTED_CHAIN_IDS, OLD_TOKEN_ADDRESS } from '@/config/contracts';

export default function DashboardPage() {
  const { address, isConnected } = useAccount();

  // Read total supply (from BSC)
  const bscToken = CONTRACTS[56]?.token;
  const { data: totalSupply } = useReadContract({
    address: bscToken,
    abi: TOKEN_ABI,
    functionName: 'totalSupply',
    query: { enabled: !!bscToken },
  });

  // Read total tax collected
  const { data: totalTax } = useReadContract({
    address: bscToken,
    abi: TOKEN_ABI,
    functionName: 'totalTaxCollected',
    query: { enabled: !!bscToken },
  });

  // Migration stats
  const migrationAddress = CONTRACTS[56]?.migration;
  const { data: totalMigrated } = useReadContract({
    address: migrationAddress,
    abi: MIGRATION_ABI,
    functionName: 'totalMigrated',
    query: { enabled: !!migrationAddress },
  });

  // Per-chain balances for connected user
  const chainBalances = SUPPORTED_CHAIN_IDS.map(chainId => {
    const tokenAddr = CONTRACTS[chainId]?.token;
    const { data: balance, isLoading } = useReadContract({
      address: tokenAddr,
      abi: TOKEN_ABI,
      functionName: 'balanceOf',
      args: address ? [address] : undefined,
      query: { enabled: !!address && !!tokenAddr },
    });
    return { chainId, balance: balance as bigint | undefined, isLoading };
  });

  // Migration percentage
  const migrationPercent = totalMigrated && totalSupply && totalSupply > BigInt(0)
    ? Number((totalMigrated as bigint) * BigInt(10000) / (totalSupply as bigint)) / 100
    : 0;

  return (
    <div style={{
      flex: 1,
      padding: 'var(--space-6)',
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
    }}>
      <div style={{ width: '100%', maxWidth: 900 }}>
        <h1 style={{ fontSize: '1.75rem', marginBottom: 'var(--space-8)', textAlign: 'center' }}>
          Dashboard
        </h1>

        {/* Top Stats */}
        <div style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))',
          gap: 'var(--space-4)',
          marginBottom: 'var(--space-8)',
        }}>
          <StatCard
            label="Total Supply"
            value={formatTokenAmount(totalSupply as bigint | undefined)}
            suffix={TOKEN_SYMBOL}
          />
          <StatCard
            label="Migrated"
            value={`${migrationPercent.toFixed(1)}%`}
            suffix={totalMigrated ? formatTokenAmount(totalMigrated as bigint) : '0'}
          />
          <StatCard
            label="Chains Active"
            value={SUPPORTED_CHAIN_IDS.length.toString()}
            suffix="networks"
          />
          <StatCard
            label="Tax Collected"
            value={formatTokenAmount(totalTax as bigint | undefined)}
            suffix={TOKEN_SYMBOL}
          />
        </div>

        {/* Migration Progress */}
        <div className="glass-card glass-card-no-hover" style={{ padding: 'var(--space-6)', marginBottom: 'var(--space-8)' }}>
          <h2 style={{ fontSize: '1rem', marginBottom: 'var(--space-4)', color: 'var(--text-secondary)' }}>
            Migration Progress
          </h2>
          <div className="progress-track" style={{ marginBottom: 'var(--space-3)' }}>
            <div className="progress-fill" style={{ width: `${Math.min(migrationPercent, 100)}%` }} />
          </div>
          <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.8125rem' }}>
            <span className="mono" style={{ color: 'var(--accent)' }}>
              {formatTokenAmount(totalMigrated as bigint | undefined)} migrated
            </span>
            <span style={{ color: 'var(--text-muted)' }}>
              {migrationPercent.toFixed(1)}%
            </span>
          </div>
        </div>

        {/* Chain Balances */}
        <h2 style={{ fontSize: '1rem', marginBottom: 'var(--space-4)', color: 'var(--text-secondary)' }}>
          {isConnected ? 'Your Balances' : 'Supported Chains'}
        </h2>
        <div style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))',
          gap: 'var(--space-4)',
          marginBottom: 'var(--space-8)',
        }}>
          {chainBalances.map(({ chainId, balance, isLoading }) => {
            const info = CHAIN_INFO[chainId];
            return (
              <div key={chainId} className="glass-card glass-card-no-hover" style={{ padding: 'var(--space-4)', textAlign: 'center' }}>
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 'var(--space-2)', marginBottom: 'var(--space-3)' }}>
                  <span className={`chain-dot ${info?.dotClass || ''}`} />
                  <span style={{ fontWeight: 600, fontSize: '0.9375rem' }}>{info?.name}</span>
                </div>
                <div className="mono" style={{ fontSize: '1.125rem', marginBottom: 'var(--space-1)' }}>
                  {isLoading ? (
                    <div className="skeleton" style={{ height: 24, width: 80, margin: '0 auto' }} />
                  ) : isConnected ? (
                    formatTokenAmount(balance)
                  ) : '—'}
                </div>
                <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>{TOKEN_SYMBOL}</div>
              </div>
            );
          })}
        </div>

        {/* Contract Addresses */}
        <h2 style={{ fontSize: '1rem', marginBottom: 'var(--space-4)', color: 'var(--text-secondary)' }}>
          Contract Addresses
        </h2>
        <div className="glass-card glass-card-no-hover" style={{ padding: 'var(--space-4)', overflow: 'auto' }}>
          {SUPPORTED_CHAIN_IDS.map(chainId => {
            const info = CHAIN_INFO[chainId];
            const addr = CONTRACTS[chainId]?.token;
            return (
              <div key={chainId} style={{
                display: 'flex', alignItems: 'center', justifyContent: 'space-between',
                padding: 'var(--space-3) 0',
                borderBottom: '1px solid var(--glass-border)',
              }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--space-2)' }}>
                  <span className={`chain-dot ${info?.dotClass || ''}`} />
                  <span style={{ fontSize: '0.875rem' }}>{info?.name}</span>
                </div>
                <code className="mono" style={{
                  fontSize: '0.75rem',
                  color: 'var(--text-secondary)',
                  cursor: 'pointer',
                }}
                  title={addr}
                  onClick={() => addr && navigator.clipboard.writeText(addr)}
                >
                  {addr ? `${addr.slice(0, 6)}...${addr.slice(-4)}` : 'Not deployed'}
                </code>
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}

function StatCard({ label, value, suffix }: { label: string; value: string; suffix: string }) {
  return (
    <div className="glass-card glass-card-no-hover" style={{ padding: 'var(--space-4)', textAlign: 'center' }}>
      <div style={{ color: 'var(--text-secondary)', fontSize: '0.75rem', marginBottom: 'var(--space-2)', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
        {label}
      </div>
      <div className="mono" style={{ fontSize: '1.375rem', fontWeight: 700, marginBottom: 'var(--space-1)', color: 'var(--accent)' }}>
        {value}
      </div>
      <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>{suffix}</div>
    </div>
  );
}
