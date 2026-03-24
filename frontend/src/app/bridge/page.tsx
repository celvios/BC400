'use client';

import { useState, useEffect, useCallback } from 'react';
import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt, useBalance } from 'wagmi';
import { pad } from 'viem';
import { formatTokenAmount, parseTokenInput, formatNativeAmount } from '@/lib/format';
import { parseContractError } from '@/lib/errors';
import { TOKEN_ABI } from '@/config/abis/token.abi';
import { CONTRACTS, CHAIN_INFO, TOKEN_SYMBOL, SUPPORTED_CHAIN_IDS } from '@/config/contracts';

// LZ Endpoint IDs
const LZ_EIDS: Record<number, number> = {
  56:   30102,  // BSC
  1:    30101,  // Ethereum
  8453: 30184,  // Base
  146:  30332,  // Sonic
  137:  30109,  // Polygon
};

export default function BridgePage() {
  const { address, isConnected, chain } = useAccount();
  const [amount, setAmount] = useState('');
  const [dstChainId, setDstChainId] = useState<number>(1);
  const [error, setError] = useState<string | undefined>();
  const [showChainSelect, setShowChainSelect] = useState(false);

  const srcChainId = chain?.id ?? 56;
  const srcContracts = CONTRACTS[srcChainId];
  const tokenAddress = srcContracts?.token;
  const dstEid = LZ_EIDS[dstChainId];

  // Source balance
  const { data: srcBalance } = useReadContract({
    address: tokenAddress,
    abi: TOKEN_ABI,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
    query: { enabled: !!address && !!tokenAddress },
  });

  // Native balance (for gas display)
  const { data: nativeBalance } = useBalance({ address });

  // Quote fee
  const parsedAmount = parseTokenInput(amount || '0');
  const sendParam = {
    dstEid: dstEid ?? 0,
    to: address ? pad(address) : pad('0x0000000000000000000000000000000000000000' as `0x${string}`) ,
    amountLD: parsedAmount,
    minAmountLD: parsedAmount,
    extraOptions: '0x' as `0x${string}`,
    composeMsg: '0x' as `0x${string}`,
    oftCmd: '0x' as `0x${string}`,
  };

  const { data: quotedFee, isLoading: feeLoading } = useReadContract({
    address: tokenAddress,
    abi: TOKEN_ABI,
    functionName: 'quoteSend',
    args: [sendParam, false],
    query: {
      enabled: !!tokenAddress && parsedAmount > BigInt(0) && !!dstEid && !!address,
      refetchInterval: 30000, // Auto-refresh every 30s
    },
  });

  const nativeFee = quotedFee ? (quotedFee as { nativeFee: bigint }).nativeFee : undefined;

  // Send bridge tx
  const { writeContract, data: bridgeTxHash, isPending } = useWriteContract();
  const { isSuccess: bridgeConfirmed } = useWaitForTransactionReceipt({ hash: bridgeTxHash });

  function handleBridge() {
    if (!tokenAddress || !address || !nativeFee) return;
    setError(undefined);
    try {
      writeContract({
        address: tokenAddress,
        abi: TOKEN_ABI,
        functionName: 'send',
        args: [
          sendParam,
          { nativeFee, lzTokenFee: BigInt(0) },
          address,
        ],
        value: nativeFee,
      });
    } catch (e) {
      setError(parseContractError(e));
    }
  }

  const handleMax = useCallback(() => {
    if (srcBalance) {
      const whole = (srcBalance as bigint) / BigInt(10 ** 18);
      const frac = (srcBalance as bigint) % BigInt(10 ** 18);
      const fracStr = frac.toString().padStart(18, '0').replace(/0+$/, '');
      setAmount(fracStr ? `${whole}.${fracStr}` : whole.toString());
    }
  }, [srcBalance]);

  // Available destination chains
  const dstChains = SUPPORTED_CHAIN_IDS.filter(id => id !== srcChainId);

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
        maxWidth: 520,
        padding: 'var(--space-8)',
      }}>
        <h1 style={{ fontSize: '1.5rem', marginBottom: 'var(--space-6)', textAlign: 'center' }}>
          Bridge Tokens
        </h1>

        {!isConnected && (
          <div style={{ textAlign: 'center', padding: 'var(--space-8) 0', color: 'var(--text-secondary)' }}>
            Connect your wallet to bridge tokens
          </div>
        )}

        {isConnected && !bridgeConfirmed && (
          <>
            {/* FROM */}
            <div style={{ marginBottom: 'var(--space-4)' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 'var(--space-2)' }}>
                <span style={{ color: 'var(--text-secondary)', fontSize: '0.875rem' }}>FROM</span>
                <span style={{ color: 'var(--text-muted)', fontSize: '0.8125rem' }}>
                  Balance: <span className="mono">{formatTokenAmount(srcBalance as bigint | undefined)}</span>
                </span>
              </div>
              <div style={{
                display: 'flex', alignItems: 'center', gap: 'var(--space-3)',
                padding: 'var(--space-3)',
                background: 'var(--glass-bg)',
                borderRadius: 'var(--radius-md)',
                marginBottom: 'var(--space-2)',
              }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--space-2)' }}>
                  <span className={`chain-dot ${CHAIN_INFO[srcChainId]?.dotClass || ''}`} />
                  <span style={{ fontWeight: 600, fontSize: '0.9375rem' }}>
                    {CHAIN_INFO[srcChainId]?.name || 'Unknown'}
                  </span>
                </div>
              </div>
              <div style={{ position: 'relative' }}>
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
            </div>

            {/* Swap Arrow */}
            <div style={{ textAlign: 'center', margin: 'var(--space-2) 0', color: 'var(--text-muted)', fontSize: '1.25rem' }}>↓</div>

            {/* TO */}
            <div style={{ marginBottom: 'var(--space-6)' }}>
              <span style={{ color: 'var(--text-secondary)', fontSize: '0.875rem', marginBottom: 'var(--space-2)', display: 'block' }}>TO</span>
              <div style={{ position: 'relative' }}>
                <button
                  onClick={() => setShowChainSelect(!showChainSelect)}
                  className="glass-btn glass-btn-ghost"
                  style={{
                    width: '100%', justifyContent: 'space-between',
                    padding: 'var(--space-3) var(--space-4)',
                    background: 'var(--glass-bg)',
                    border: '1px solid var(--glass-border)',
                    borderRadius: 'var(--radius-md)',
                  }}
                >
                  <span style={{ display: 'flex', alignItems: 'center', gap: 'var(--space-2)' }}>
                    <span className={`chain-dot ${CHAIN_INFO[dstChainId]?.dotClass || ''}`} />
                    {CHAIN_INFO[dstChainId]?.name || 'Select chain'}
                  </span>
                  <span>▾</span>
                </button>
                {showChainSelect && (
                  <div style={{
                    position: 'absolute', top: '100%', left: 0, right: 0, zIndex: 10,
                    marginTop: 4,
                    background: 'rgba(13, 21, 40, 0.98)',
                    borderRadius: 'var(--radius-md)',
                    border: '1px solid var(--glass-border)',
                    overflow: 'hidden',
                  }}>
                    {dstChains.map(id => (
                      <button
                        key={id}
                        onClick={() => { setDstChainId(id); setShowChainSelect(false); }}
                        style={{
                          display: 'flex', alignItems: 'center', gap: 'var(--space-2)',
                          width: '100%', padding: 'var(--space-3) var(--space-4)',
                          background: id === dstChainId ? 'var(--accent-dim)' : 'transparent',
                          border: 'none', color: 'var(--text-primary)', cursor: 'pointer',
                          fontSize: '0.9375rem',
                        }}
                      >
                        <span className={`chain-dot ${CHAIN_INFO[id]?.dotClass || ''}`} />
                        {CHAIN_INFO[id]?.name}
                      </button>
                    ))}
                  </div>
                )}
              </div>
            </div>

            {/* Fee Info */}
            <div style={{
              padding: 'var(--space-4)',
              background: 'var(--glass-bg)',
              borderRadius: 'var(--radius-lg)',
              marginBottom: 'var(--space-6)',
            }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 'var(--space-2)' }}>
                <span style={{ color: 'var(--text-secondary)', fontSize: '0.8125rem' }}>Bridge Fee</span>
                <span className="mono" style={{ fontSize: '0.8125rem' }}>
                  {feeLoading ? '...' : nativeFee
                    ? formatNativeAmount(nativeFee, CHAIN_INFO[srcChainId]?.symbol || 'ETH')
                    : '—'}
                </span>
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 'var(--space-2)' }}>
                <span style={{ color: 'var(--text-secondary)', fontSize: '0.8125rem' }}>Est. Time</span>
                <span style={{ fontSize: '0.8125rem' }}>1–5 minutes</span>
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                <span style={{ color: 'var(--text-secondary)', fontSize: '0.8125rem' }}>You Receive</span>
                <span className="mono" style={{ fontSize: '0.8125rem', color: 'var(--accent)' }}>
                  {amount ? `${amount} ${TOKEN_SYMBOL}` : '—'}
                </span>
              </div>
            </div>

            {/* Bridge Button */}
            <button
              className="glass-btn glass-btn-primary"
              style={{ width: '100%', padding: 'var(--space-4)' }}
              disabled={!amount || parsedAmount === BigInt(0) || !nativeFee || isPending}
              onClick={handleBridge}
            >
              {isPending ? (
                <><div className="spinner" /> Bridging...</>
              ) : 'Bridge Tokens'}
            </button>

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
        {bridgeConfirmed && (
          <div className="success-glow" style={{ textAlign: 'center', padding: 'var(--space-6) 0' }}>
            <div style={{ fontSize: '3rem', marginBottom: 'var(--space-4)' }}>🌉</div>
            <h2 style={{ color: 'var(--success)', marginBottom: 'var(--space-3)' }}>Bridge Sent!</h2>
            <p style={{ color: 'var(--text-secondary)', marginBottom: 'var(--space-2)', fontSize: '0.875rem' }}>
              Your tokens are being delivered to {CHAIN_INFO[dstChainId]?.name}
            </p>
            <p style={{ color: 'var(--text-muted)', marginBottom: 'var(--space-4)', fontSize: '0.8125rem' }}>
              Estimated arrival: 1–5 minutes
            </p>
            {bridgeTxHash && (
              <a
                href={`${chain?.blockExplorers?.default?.url || '#'}/tx/${bridgeTxHash}`}
                target="_blank"
                rel="noopener noreferrer"
                className="glass-btn glass-btn-secondary"
                style={{ display: 'inline-flex' }}
              >
                View Transaction ↗
              </a>
            )}
          </div>
        )}
      </div>
    </div>
  );
}
