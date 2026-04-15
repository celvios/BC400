'use client';

import { useState, useCallback } from 'react';
import {
  useAccount,
  useReadContract,
  useWriteContract,
  useWaitForTransactionReceipt,
  useSwitchChain,
} from 'wagmi';
import { keccak256, toBytes, isAddress } from 'viem';
import { TOKEN_ABI } from '@/config/abis/token.abi';
import { CONTRACTS, CHAIN_INFO, TOKEN_SYMBOL, SUPPORTED_CHAIN_IDS } from '@/config/contracts';

// ─── helpers ──────────────────────────────────────────────────────────────────

const ADMIN_ROLE_HASH = keccak256(toBytes('ADMIN_ROLE'));

function fmtCountdown(seconds: number): string {
  if (seconds <= 0) return 'Ended';
  const m = Math.floor(seconds / 60);
  const s = seconds % 60;
  return `${m}m ${s}s remaining`;
}

// ─── tiny shared components ───────────────────────────────────────────────────

function SectionTitle({ children }: { children: React.ReactNode }) {
  return (
    <h2 style={{
      fontSize: '0.75rem',
      letterSpacing: '0.12em',
      textTransform: 'uppercase',
      color: 'var(--text-secondary)',
      marginBottom: 'var(--space-4)',
    }}>
      {children}
    </h2>
  );
}

function StatusBadge({ ok, yes, no }: { ok: boolean; yes: string; no: string }) {
  return (
    <span className="badge" style={{
      background: ok ? 'var(--success-dim)' : 'var(--error-dim)',
      border: `1px solid ${ok ? 'var(--success)' : 'var(--error)'}`,
      color: ok ? 'var(--success)' : 'var(--error)',
      fontFamily: 'JetBrains Mono, monospace',
      fontSize: '0.75rem',
    }}>
      {ok ? yes : no}
    </span>
  );
}

function TxButton({
  onClick,
  loading,
  disabled,
  danger,
  children,
}: {
  onClick: () => void;
  loading: boolean;
  disabled?: boolean;
  danger?: boolean;
  children: React.ReactNode;
}) {
  return (
    <button
      className={`glass-btn ${danger ? 'glass-btn-danger' : 'glass-btn-primary'}`}
      onClick={onClick}
      disabled={disabled || loading}
      style={{ minWidth: 120 }}
    >
      {loading ? (
        <span style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
          <span className="spinner" style={{
            width: 14, height: 14, border: '2px solid currentColor',
            borderTopColor: 'transparent', borderRadius: '50%',
            animation: 'spin 0.7s linear infinite', display: 'inline-block',
          }} />
          Confirming…
        </span>
      ) : children}
    </button>
  );
}

// ─── address checker row ──────────────────────────────────────────────────────

function AddressStatusRow({
  tokenAddress,
  label,
  readFn,
  setFn,
  addLabel,
  removeLabel,
  danger,
}: {
  tokenAddress: `0x${string}`;
  label: string;
  readFn: 'whitelisted' | 'blacklisted';
  setFn: 'setWhitelisted' | 'setBlacklisted';
  addLabel: string;
  removeLabel: string;
  danger?: boolean;
}) {
  const [addr, setAddr] = useState('');
  const [checking, setChecking] = useState<`0x${string}` | null>(null);

  const { data: status } = useReadContract({
    address: tokenAddress,
    abi: TOKEN_ABI,
    functionName: readFn,
    args: checking ? [checking] : undefined,
    query: { enabled: !!checking },
  });

  const { writeContract, data: txHash, isPending } = useWriteContract();
  const { isLoading: isMining } = useWaitForTransactionReceipt({ hash: txHash });

  const isValid = isAddress(addr);

  const check = () => {
    if (isValid) setChecking(addr as `0x${string}`);
  };

  const write = (value: boolean) => {
    if (!isValid) return;
    writeContract({
      address: tokenAddress,
      abi: TOKEN_ABI,
      functionName: setFn,
      args: [addr as `0x${string}`, value],
    });
  };

  return (
    <div style={{ marginBottom: 'var(--space-6)' }}>
      <div style={{ fontSize: '0.8125rem', color: 'var(--text-muted)', marginBottom: 'var(--space-2)' }}>
        {label}
      </div>
      <div style={{ display: 'flex', gap: 'var(--space-2)', flexWrap: 'wrap', alignItems: 'center' }}>
        <input
          className={`glass-input${!addr || isValid ? '' : ' glass-input-error'}`}
          style={{ flex: '1 1 260px', maxWidth: 400 }}
          placeholder="0x wallet address"
          value={addr}
          onChange={e => { setAddr(e.target.value); setChecking(null); }}
        />
        <button className="glass-btn glass-btn-ghost" onClick={check} disabled={!isValid}>
          Check
        </button>
        <TxButton
          onClick={() => write(true)}
          loading={isPending || isMining}
          disabled={!isValid}
          danger={danger}
        >
          {addLabel}
        </TxButton>
        <TxButton
          onClick={() => write(false)}
          loading={isPending || isMining}
          disabled={!isValid}
        >
          {removeLabel}
        </TxButton>
      </div>

      {checking && (
        <div style={{ marginTop: 'var(--space-2)', fontSize: '0.8125rem' }}>
          <span className="mono" style={{ color: 'var(--text-muted)' }}>{checking.slice(0, 10)}…</span>
          {' '}
          {status === undefined
            ? <span style={{ color: 'var(--text-muted)' }}>Loading…</span>
            : <StatusBadge ok={status as boolean} yes="YES" no="NO" />
          }
        </div>
      )}

      {txHash && (
        <div style={{ marginTop: 'var(--space-2)', fontSize: '0.75rem', color: 'var(--success)' }}>
          Tx submitted — {txHash.slice(0, 16)}…
        </div>
      )}
    </div>
  );
}

// ─── per-chain panel ──────────────────────────────────────────────────────────

function ChainAdminPanel({ chainId }: { chainId: number }) {
  const { address, chainId: connectedChainId } = useAccount();
  const { switchChain } = useSwitchChain();
  const info = CHAIN_INFO[chainId];
  const tokenAddress = CONTRACTS[chainId]?.token;

  // Check ADMIN_ROLE
  const { data: isAdmin } = useReadContract({
    address: tokenAddress,
    abi: TOKEN_ABI,
    functionName: 'hasRole',
    args: address ? [ADMIN_ROLE_HASH, address] : undefined,
    query: { enabled: !!address && !!tokenAddress },
  });

  // Read on-chain state
  const { data: launchTime, refetch: refetchLaunch } = useReadContract({
    address: tokenAddress,
    abi: TOKEN_ABI,
    functionName: 'launchTime',
    query: { enabled: !!tokenAddress },
  });

  const { data: isWhitelistActive, refetch: refetchActive } = useReadContract({
    address: tokenAddress,
    abi: TOKEN_ABI,
    functionName: 'isWhitelistActive',
    query: { enabled: !!tokenAddress },
  });

  const { data: whitelistEnabled, refetch: refetchEnabled } = useReadContract({
    address: tokenAddress,
    abi: TOKEN_ABI,
    functionName: 'whitelistEnabled',
    query: { enabled: !!tokenAddress },
  });

  // Launch
  const { writeContract: writeLaunch, data: launchTxHash, isPending: launchPending } = useWriteContract();
  const { isLoading: launchMining, isSuccess: launchDone } = useWaitForTransactionReceipt({ hash: launchTxHash });

  // whitelistEnabled toggle
  const { writeContract: writeWLE, data: wleTxHash, isPending: wlePending } = useWriteContract();
  const { isLoading: wleMining } = useWaitForTransactionReceipt({ hash: wleTxHash });

  const onLaunch = useCallback(() => {
    if (!tokenAddress) return;
    writeLaunch({ address: tokenAddress, abi: TOKEN_ABI, functionName: 'launch', args: [] });
  }, [tokenAddress, writeLaunch]);

  const onToggleWLE = useCallback((enabled: boolean) => {
    if (!tokenAddress) return;
    writeWLE({ address: tokenAddress, abi: TOKEN_ABI, functionName: 'setWhitelistEnabled', args: [enabled] });
  }, [tokenAddress, writeWLE]);

  const launched = launchTime !== undefined && (launchTime as bigint) > 0n;
  const nowSec = Math.floor(Date.now() / 1000);
  const launchSec = launched ? Number(launchTime as bigint) : 0;
  const windowEnd = launchSec + 7200; // 2 hours
  const countdown = windowEnd - nowSec;
  const isOnThisChain = connectedChainId === chainId;

  return (
    <div className="glass-card" style={{ padding: 'var(--space-6)', marginBottom: 'var(--space-6)' }}>
      {/* Chain Header */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 'var(--space-6)', flexWrap: 'wrap', gap: 'var(--space-3)' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--space-3)' }}>
          <span className={`chain-dot ${info?.dotClass}`} style={{ width: 12, height: 12 }} />
          <h2 style={{ fontSize: '1rem', margin: 0 }}>{info?.name}</h2>
          {isAdmin === true && (
            <span className="badge" style={{
              background: 'var(--accent-dim)', border: '1px solid var(--accent)',
              color: 'var(--accent)', fontSize: '0.7rem',
            }}>
              ADMIN
            </span>
          )}
          {isAdmin === false && (
            <span className="badge" style={{
              background: 'var(--error-dim)', border: '1px solid var(--error)',
              color: 'var(--error)', fontSize: '0.7rem',
            }}>
              NOT ADMIN
            </span>
          )}
        </div>

        {!isOnThisChain && (
          <button
            className="glass-btn glass-btn-ghost"
            style={{ fontSize: '0.8125rem', padding: '6px 14px' }}
            onClick={() => switchChain({ chainId })}
          >
            Switch to {info?.name}
          </button>
        )}
      </div>

      {/* Status Row */}
      <div style={{
        display: 'grid',
        gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))',
        gap: 'var(--space-4)',
        marginBottom: 'var(--space-6)',
      }}>
        <div className="glass-card glass-card-no-hover" style={{ padding: 'var(--space-4)', textAlign: 'center' }}>
          <div style={{ color: 'var(--text-muted)', fontSize: '0.7rem', marginBottom: 6 }}>LAUNCHED</div>
          <StatusBadge ok={launched} yes="YES" no="NO" />
        </div>
        <div className="glass-card glass-card-no-hover" style={{ padding: 'var(--space-4)', textAlign: 'center' }}>
          <div style={{ color: 'var(--text-muted)', fontSize: '0.7rem', marginBottom: 6 }}>WHITELIST ACTIVE</div>
          <StatusBadge ok={!!isWhitelistActive} yes="ACTIVE" no="INACTIVE" />
        </div>
        <div className="glass-card glass-card-no-hover" style={{ padding: 'var(--space-4)', textAlign: 'center' }}>
          <div style={{ color: 'var(--text-muted)', fontSize: '0.7rem', marginBottom: 6 }}>MANUAL LOCK</div>
          <StatusBadge ok={!!whitelistEnabled} yes="ON" no="OFF" />
        </div>
        {launched && (
          <div className="glass-card glass-card-no-hover" style={{ padding: 'var(--space-4)', textAlign: 'center' }}>
            <div style={{ color: 'var(--text-muted)', fontSize: '0.7rem', marginBottom: 6 }}>2HR WINDOW</div>
            <span className="mono" style={{ fontSize: '0.8125rem', color: countdown > 0 ? 'var(--warning)' : 'var(--text-muted)' }}>
              {fmtCountdown(countdown)}
            </span>
          </div>
        )}
      </div>

      {/* Disabled state if not admin or wrong chain */}
      {(!isOnThisChain || isAdmin === false) && (
        <div style={{
          padding: 'var(--space-4)',
          border: '1px dashed var(--glass-border)',
          borderRadius: 'var(--radius-md)',
          textAlign: 'center',
          color: 'var(--text-muted)',
          fontSize: '0.875rem',
          marginBottom: 'var(--space-6)',
        }}>
          {!isOnThisChain
            ? `Switch your wallet to ${info?.name} to manage this chain`
            : `Connected wallet does not hold ADMIN_ROLE on ${info?.name}`}
        </div>
      )}

      {/* Controls — only shown when on correct chain and is admin */}
      {isOnThisChain && isAdmin !== false && (
        <>
          {/* Launch */}
          {!launched && (
            <div style={{ marginBottom: 'var(--space-6)' }}>
              <SectionTitle>Launch Token</SectionTitle>
              <div style={{
                padding: 'var(--space-4)',
                background: 'var(--warning-dim)',
                border: '1px solid var(--warning)',
                borderRadius: 'var(--radius-md)',
                marginBottom: 'var(--space-4)',
                fontSize: '0.8125rem',
                color: 'var(--warning)',
              }}>
                Calling <code>launch()</code> starts the 2-hour whitelist window. After 2 hrs the token opens to everyone. This action is <strong>irreversible</strong> — whitelist all wallets first.
              </div>
              <TxButton
                onClick={onLaunch}
                loading={launchPending || launchMining}
                danger={false}
              >
                Launch BC400
              </TxButton>
              {launchDone && (
                <div style={{ marginTop: 'var(--space-3)', color: 'var(--success)', fontSize: '0.8125rem' }}>
                  Token launched successfully.
                </div>
              )}
            </div>
          )}

          {/* Manual whitelist lock */}
          <div style={{ marginBottom: 'var(--space-6)' }}>
            <SectionTitle>Manual Whitelist Lock</SectionTitle>
            <p style={{ fontSize: '0.8125rem', color: 'var(--text-muted)', marginBottom: 'var(--space-4)' }}>
              Force whitelist-only mode ON at any time (independent of the 2hr window). Turn OFF to open trading to everyone.
            </p>
            <div style={{ display: 'flex', gap: 'var(--space-3)' }}>
              <TxButton
                onClick={() => onToggleWLE(true)}
                loading={wlePending || wleMining}
                disabled={!!whitelistEnabled}
              >
                Lock (Enable)
              </TxButton>
              <TxButton
                onClick={() => onToggleWLE(false)}
                loading={wlePending || wleMining}
                disabled={!whitelistEnabled}
                danger
              >
                Unlock (Disable)
              </TxButton>
            </div>
          </div>

          {/* Whitelist management */}
          <div style={{ marginBottom: 'var(--space-6)' }}>
            <SectionTitle>Whitelist — Allowed Wallets</SectionTitle>
            <p style={{ fontSize: '0.8125rem', color: 'var(--text-muted)', marginBottom: 'var(--space-4)' }}>
              Only whitelisted wallets can buy/sell/transfer during the whitelist window. Add all pre-sale wallets before calling launch.
            </p>
            <AddressStatusRow
              tokenAddress={tokenAddress}
              label="Enter wallet address to check, add, or remove"
              readFn="whitelisted"
              setFn="setWhitelisted"
              addLabel="Whitelist"
              removeLabel="Remove"
            />
          </div>

          {/* Blacklist management */}
          <div>
            <SectionTitle>Blacklist — Blocked Wallets</SectionTitle>
            <p style={{ fontSize: '0.8125rem', color: 'var(--text-muted)', marginBottom: 'var(--space-4)' }}>
              Blacklisted wallets cannot send or receive BC400 under any circumstance, regardless of whitelist status. Permanent until removed.
            </p>
            <AddressStatusRow
              tokenAddress={tokenAddress}
              label="Enter wallet address to check, add, or remove"
              readFn="blacklisted"
              setFn="setBlacklisted"
              addLabel="Blacklist"
              removeLabel="Remove"
              danger
            />
          </div>
        </>
      )}
    </div>
  );
}

// ─── page ─────────────────────────────────────────────────────────────────────

export default function AdminPage() {
  const { isConnected } = useAccount();

  return (
    <div style={{
      flex: 1,
      padding: 'var(--space-6)',
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
    }}>
      <div style={{ width: '100%', maxWidth: 860 }}>
        <h1 style={{ fontSize: '1.75rem', marginBottom: 'var(--space-2)', textAlign: 'center' }}>
          Admin Panel
        </h1>
        <p style={{ textAlign: 'center', color: 'var(--text-muted)', fontSize: '0.875rem', marginBottom: 'var(--space-8)' }}>
          Whitelist, blacklist, and launch controls for BC400 on each chain.
          Requires <code style={{ color: 'var(--accent)' }}>ADMIN_ROLE</code> wallet connected to the correct network.
        </p>

        {!isConnected && (
          <div style={{
            padding: 'var(--space-6)',
            border: '1px dashed var(--glass-border)',
            borderRadius: 'var(--radius-lg)',
            textAlign: 'center',
            color: 'var(--text-muted)',
            marginBottom: 'var(--space-8)',
          }}>
            Connect your admin wallet to manage token settings.
          </div>
        )}

        {SUPPORTED_CHAIN_IDS.map(chainId => (
          <ChainAdminPanel key={chainId} chainId={chainId} />
        ))}
      </div>
    </div>
  );
}
