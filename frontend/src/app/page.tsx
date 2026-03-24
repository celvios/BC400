'use client';

import { useState, useEffect } from 'react';
import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { formatTokenAmount, parseTokenInput } from '@/lib/format';
import { parseContractError } from '@/lib/errors';
import { TOKEN_ABI } from '@/config/abis/token.abi';
import { MIGRATION_ABI } from '@/config/abis/migration.abi';
import { CONTRACTS, OLD_TOKEN_ADDRESS, TOKEN_SYMBOL } from '@/config/contracts';

type MigrationState = 
  | 'idle' | 'wrong_network' | 'loading_balances' | 'no_old_tokens'
  | 'deadline_passed' | 'ready' | 'approving' | 'approval_failed'
  | 'approved' | 'migrating' | 'migration_failed' | 'success';

export default function MigratePage() {
  const { address, isConnected, chain } = useAccount();
  const [amount, setAmount] = useState('');
  const [state, setState] = useState<MigrationState>('idle');
  const [error, setError] = useState<string | undefined>();

  const bscContracts = CONTRACTS[56];
  const migrationAddress = bscContracts?.migration;
  const newTokenAddress = bscContracts?.token;
  const isBSC = chain?.id === 56;

  // Read old token balance
  const { data: oldBalance } = useReadContract({
    address: OLD_TOKEN_ADDRESS,
    abi: TOKEN_ABI,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
    query: { enabled: !!address && isBSC },
  });

  // Read new token balance
  const { data: newBalance } = useReadContract({
    address: newTokenAddress,
    abi: TOKEN_ABI,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
    query: { enabled: !!address && isBSC },
  });

  // Read allowance
  const { data: allowance } = useReadContract({
    address: OLD_TOKEN_ADDRESS,
    abi: TOKEN_ABI,
    functionName: 'allowance',
    args: address && migrationAddress ? [address, migrationAddress] : undefined,
    query: { enabled: !!address && !!migrationAddress && isBSC },
  });

  // Read migration deadline
  const { data: deadline } = useReadContract({
    address: migrationAddress,
    abi: MIGRATION_ABI,
    functionName: 'deadline',
    query: { enabled: !!migrationAddress && isBSC },
  });

  // Read migration active
  const { data: isActive } = useReadContract({
    address: migrationAddress,
    abi: MIGRATION_ABI,
    functionName: 'active',
    query: { enabled: !!migrationAddress && isBSC },
  });

  // Read total migrated
  const { data: totalMigrated } = useReadContract({
    address: migrationAddress,
    abi: MIGRATION_ABI,
    functionName: 'totalMigrated',
    query: { enabled: !!migrationAddress && isBSC },
  });

  // Approve
  const { writeContract: approveWrite, data: approveTxHash, isPending: isApproving } = useWriteContract();
  const { isSuccess: approveConfirmed } = useWaitForTransactionReceipt({ hash: approveTxHash });

  // Migrate
  const { writeContract: migrateWrite, data: migrateTxHash, isPending: isMigrating } = useWriteContract();
  const { isSuccess: migrateConfirmed } = useWaitForTransactionReceipt({ hash: migrateTxHash });

  // Determine state
  useEffect(() => {
    if (!isConnected) { setState('idle'); return; }
    if (!isBSC) { setState('wrong_network'); return; }
    if (migrateConfirmed) { setState('success'); return; }
    if (isMigrating) { setState('migrating'); return; }
    if (approveConfirmed || (allowance !== undefined && parseTokenInput(amount || '0') > BigInt(0) && allowance >= parseTokenInput(amount || '0'))) {
      setState('approved'); return;
    }
    if (isApproving) { setState('approving'); return; }
    if (deadline !== undefined && Number(deadline) * 1000 < Date.now()) { setState('deadline_passed'); return; }
    if (oldBalance !== undefined && oldBalance === BigInt(0)) { setState('no_old_tokens'); return; }
    setState('ready');
  }, [isConnected, isBSC, oldBalance, deadline, allowance, amount, isApproving, approveConfirmed, isMigrating, migrateConfirmed]);

  // Countdown
  const [timeLeft, setTimeLeft] = useState('');
  useEffect(() => {
    if (!deadline) return;
    const update = () => {
      const ms = Number(deadline) * 1000 - Date.now();
      if (ms <= 0) { setTimeLeft('Expired'); return; }
      const d = Math.floor(ms / 86400000);
      const h = Math.floor((ms % 86400000) / 3600000);
      const m = Math.floor((ms % 3600000) / 60000);
      setTimeLeft(`${d}d ${h}h ${m}m`);
    };
    update();
    const interval = setInterval(update, 60000);
    return () => clearInterval(interval);
  }, [deadline]);

  const parsedAmount = parseTokenInput(amount || '0');
  const isApproved = allowance !== undefined && parsedAmount > BigInt(0) && allowance >= parsedAmount;
  const step = isApproved ? 2 : 1;

  function handleApprove() {
    if (!migrationAddress) return;
    setError(undefined);
    try {
      approveWrite({
        address: OLD_TOKEN_ADDRESS,
        abi: TOKEN_ABI,
        functionName: 'approve',
        args: [migrationAddress, parsedAmount],
      });
    } catch (e) {
      setError(parseContractError(e));
      setState('approval_failed');
    }
  }

  function handleMigrate() {
    if (!migrationAddress) return;
    setError(undefined);
    try {
      migrateWrite({
        address: migrationAddress,
        abi: MIGRATION_ABI,
        functionName: 'migrate',
        args: [parsedAmount],
      });
    } catch (e) {
      setError(parseContractError(e));
      setState('migration_failed');
    }
  }

  function handleMax() {
    if (oldBalance) {
      const whole = oldBalance / BigInt(10 ** 18);
      const frac = oldBalance % BigInt(10 ** 18);
      const fracStr = frac.toString().padStart(18, '0').replace(/0+$/, '');
      setAmount(fracStr ? `${whole}.${fracStr}` : whole.toString());
    }
  }

  return (
    <div style={{
      flex: 1,
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      padding: 'var(--space-6)',
    }}>
      <div className="glass-card glass-card-elevated glass-card-no-hover" style={{
        width: '100%',
        maxWidth: 480,
        padding: 'var(--space-8)',
      }}>
        {/* Header */}
        <div style={{ textAlign: 'center', marginBottom: 'var(--space-6)' }}>
          <h1 style={{ fontSize: '1.5rem', marginBottom: 'var(--space-2)' }}>Token Migration</h1>
          <p style={{ color: 'var(--text-secondary)', fontSize: '0.875rem' }}>
            Swap your old tokens 1:1 for new {TOKEN_SYMBOL}
          </p>
          {deadline && (
            <div style={{ marginTop: 'var(--space-3)' }}>
              {state === 'deadline_passed' ? (
                <span className="badge badge-error">Migration Closed</span>
              ) : (
                <span className="badge badge-accent">⏱ {timeLeft} remaining</span>
              )}
            </div>
          )}
        </div>

        {/* Not Connected */}
        {state === 'idle' && (
          <div style={{ textAlign: 'center', padding: 'var(--space-8) 0', color: 'var(--text-secondary)' }}>
            Connect your wallet to begin migration
          </div>
        )}

        {/* Wrong Network */}
        {state === 'wrong_network' && (
          <div style={{ textAlign: 'center', padding: 'var(--space-8) 0' }}>
            <p style={{ color: 'var(--warning)', marginBottom: 'var(--space-4)' }}>
              Please switch to BNB Chain
            </p>
            <p style={{ color: 'var(--text-secondary)', fontSize: '0.875rem' }}>
              Migration is only available on BSC
            </p>
          </div>
        )}

        {/* Main Content */}
        {isConnected && isBSC && state !== 'success' && (
          <>
            {/* Balances */}
            <div style={{
              display: 'flex',
              flexDirection: 'column',
              gap: 'var(--space-3)',
              marginBottom: 'var(--space-6)',
              padding: 'var(--space-4)',
              background: 'var(--glass-bg)',
              borderRadius: 'var(--radius-lg)',
            }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <span style={{ color: 'var(--text-secondary)', fontSize: '0.875rem' }}>Old Token</span>
                <span className="mono" style={{ fontSize: '1rem' }}>
                  {formatTokenAmount(oldBalance as bigint | undefined)}
                </span>
              </div>
              <div style={{ height: 1, background: 'var(--glass-border)' }} />
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <span style={{ color: 'var(--text-secondary)', fontSize: '0.875rem' }}>New {TOKEN_SYMBOL}</span>
                <span className="mono" style={{ fontSize: '1rem', color: 'var(--accent)' }}>
                  {formatTokenAmount(newBalance as bigint | undefined)}
                </span>
              </div>
            </div>

            {/* Input */}
            {state !== 'deadline_passed' && state !== 'no_old_tokens' && (
              <>
                <div style={{ marginBottom: 'var(--space-2)' }}>
                  <label style={{ color: 'var(--text-secondary)', fontSize: '0.875rem' }}>Amount to migrate</label>
                </div>
                <div style={{ position: 'relative', marginBottom: 'var(--space-6)' }}>
                  <input
                    type="text"
                    inputMode="decimal"
                    className="glass-input"
                    placeholder="0.00"
                    value={amount}
                    onChange={e => {
                      const v = e.target.value.replace(/[^0-9.]/g, '');
                      if (v.split('.').length <= 2) setAmount(v);
                    }}
                    style={{ paddingRight: 80 }}
                  />
                  <button
                    onClick={handleMax}
                    className="glass-btn glass-btn-ghost"
                    style={{
                      position: 'absolute', right: 8, top: '50%', transform: 'translateY(-50%)',
                      padding: '4px 12px', fontSize: '0.75rem',
                    }}
                  >
                    MAX
                  </button>
                </div>

                {/* Step Indicator */}
                <div className="step-indicator" style={{ justifyContent: 'center', marginBottom: 'var(--space-6)' }}>
                  <div className={`step-dot ${step >= 1 ? (isApproved ? 'step-dot-complete' : 'step-dot-active') : ''}`}>1</div>
                  <div className={`step-line ${isApproved ? 'step-line-active' : ''}`} />
                  <div className={`step-dot ${step >= 2 ? 'step-dot-active' : ''}`}>2</div>
                </div>
                <div style={{ textAlign: 'center', marginBottom: 'var(--space-4)', color: 'var(--text-secondary)', fontSize: '0.8125rem' }}>
                  Step {step} of 2 — {isApproved ? 'Migrate' : 'Approve'}
                </div>

                {/* Action Button */}
                {!isApproved ? (
                  <button
                    className="glass-btn glass-btn-primary"
                    style={{ width: '100%', padding: 'var(--space-4)' }}
                    disabled={!amount || parsedAmount === BigInt(0) || isApproving}
                    onClick={handleApprove}
                  >
                    {isApproving ? (
                      <><div className="spinner" /> Approving...</>
                    ) : 'Approve Token Transfer'}
                  </button>
                ) : (
                  <button
                    className="glass-btn glass-btn-primary"
                    style={{ width: '100%', padding: 'var(--space-4)' }}
                    disabled={isMigrating}
                    onClick={handleMigrate}
                  >
                    {isMigrating ? (
                      <><div className="spinner" /> Migrating...</>
                    ) : `Migrate ${TOKEN_SYMBOL}`}
                  </button>
                )}
              </>
            )}

            {state === 'no_old_tokens' && (
              <div style={{ textAlign: 'center', padding: 'var(--space-6) 0', color: 'var(--text-secondary)' }}>
                You don&apos;t have any old tokens to migrate.
              </div>
            )}

            {/* Error */}
            {error && (
              <div style={{
                marginTop: 'var(--space-4)',
                padding: 'var(--space-3)',
                background: 'var(--error-dim)',
                borderRadius: 'var(--radius-md)',
                color: 'var(--error)',
                fontSize: '0.875rem',
                textAlign: 'center',
              }}>
                {error}
              </div>
            )}
          </>
        )}

        {/* Success */}
        {state === 'success' && (
          <div className="success-glow" style={{ textAlign: 'center', padding: 'var(--space-6) 0' }}>
            <div style={{ fontSize: '3rem', marginBottom: 'var(--space-4)' }}>✓</div>
            <h2 style={{ color: 'var(--success)', marginBottom: 'var(--space-3)' }}>Migration Complete!</h2>
            <p style={{ color: 'var(--text-secondary)', marginBottom: 'var(--space-4)' }}>
              Your tokens have been migrated to {TOKEN_SYMBOL}
            </p>
            {migrateTxHash && (
              <a
                href={`https://bscscan.com/tx/${migrateTxHash}`}
                target="_blank"
                rel="noopener noreferrer"
                className="glass-btn glass-btn-secondary"
                style={{ display: 'inline-flex' }}
              >
                View on BscScan ↗
              </a>
            )}
          </div>
        )}

        {/* Migration Progress */}
        {totalMigrated !== undefined && (
          <div style={{ marginTop: 'var(--space-6)', paddingTop: 'var(--space-4)', borderTop: '1px solid var(--glass-border)' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 'var(--space-2)' }}>
              <span style={{ color: 'var(--text-secondary)', fontSize: '0.75rem' }}>Total Migrated</span>
              <span className="mono" style={{ fontSize: '0.75rem', color: 'var(--text-secondary)' }}>
                {formatTokenAmount(totalMigrated as bigint)}
              </span>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
