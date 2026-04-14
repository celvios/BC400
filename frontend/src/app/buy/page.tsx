'use client';

import { useState, useEffect, useCallback } from 'react';
import {
  useAccount,
  useReadContract,
  useWriteContract,
  useWaitForTransactionReceipt,
  useBalance,
} from 'wagmi';
import { formatTokenAmount, parseTokenInput } from '@/lib/format';
import { parseContractError } from '@/lib/errors';
import { TOKEN_ABI } from '@/config/abis/token.abi';
import { ROUTER_ABI } from '@/config/abis/router.abi';
import { CONTRACTS, CHAIN_INFO, TOKEN_SYMBOL, SUPPORTED_CHAIN_IDS } from '@/config/contracts';
import { getDexConfig, type PaymentToken } from '@/config/dex';

// Minimal ERC20 ABI for balance / allowance / approve
const ERC20_ABI = [
  {
    name: 'balanceOf',
    type: 'function',
    stateMutability: 'view',
    inputs:  [{ name: 'account', type: 'address' }],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'allowance',
    type: 'function',
    stateMutability: 'view',
    inputs:  [{ name: 'owner', type: 'address' }, { name: 'spender', type: 'address' }],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'approve',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs:  [{ name: 'spender', type: 'address' }, { name: 'amount', type: 'uint256' }],
    outputs: [{ type: 'bool' }],
  },
] as const;

type BuyState =
  | 'idle'
  | 'unsupported'
  | 'no_dex'
  | 'ready'
  | 'approving'
  | 'swapping'
  | 'success';

export default function BuyPage() {
  const { address, isConnected, chain } = useAccount();
  const chainId = chain?.id ?? 56;

  const [payAmount, setPayAmount]           = useState('');
  const [selectedToken, setSelectedToken]   = useState<PaymentToken | null>(null);
  const [showTokenSelect, setShowTokenSelect] = useState(false);
  const [state, setState]                   = useState<BuyState>('idle');
  const [error, setError]                   = useState<string | undefined>();

  const isSupported = (SUPPORTED_CHAIN_IDS as readonly number[]).includes(chainId);
  const dexConfig   = getDexConfig(chainId);
  const tokenAddress = CONTRACTS[chainId]?.token;

  // When the chain changes, reset and pick the first payment token
  useEffect(() => {
    setPayAmount('');
    setError(undefined);
    if (dexConfig?.paymentTokens.length) {
      setSelectedToken(dexConfig.paymentTokens[0]);
    }
  }, [chainId]); // eslint-disable-line react-hooks/exhaustive-deps

  // ── Balances ────────────────────────────────────────────────

  const { data: nativeBalance } = useBalance({
    address,
    query: { enabled: !!address },
  });

  const { data: erc20Balance } = useReadContract({
    address: selectedToken?.address ?? undefined,
    abi: ERC20_ABI,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
    query: { enabled: !!address && !selectedToken?.isNative && !!selectedToken?.address },
  });

  const { data: bc400Balance } = useReadContract({
    address: tokenAddress,
    abi: TOKEN_ABI,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
    query: { enabled: !!address && !!tokenAddress },
  });

  // ── Allowance ───────────────────────────────────────────────

  const { data: allowance, refetch: refetchAllowance } = useReadContract({
    address: selectedToken?.address ?? undefined,
    abi: ERC20_ABI,
    functionName: 'allowance',
    args: address && dexConfig ? [address, dexConfig.routerAddress] : undefined,
    query: {
      enabled: !!address && !selectedToken?.isNative && !!selectedToken?.address && !!dexConfig,
    },
  });

  // ── Price quote ─────────────────────────────────────────────

  const payTokenDecimals = selectedToken?.decimals ?? 18;
  const parsedPayAmount  = parseTokenInput(payAmount || '0', payTokenDecimals);

  // Build swap path: native → [WETH, BC400] | ERC20 → [token, WETH, BC400]
  const quotePath: `0x${string}`[] | undefined = dexConfig && tokenAddress
    ? selectedToken?.isNative
      ? [dexConfig.wethAddress, tokenAddress]
      : selectedToken?.address
        ? [selectedToken.address, dexConfig.wethAddress, tokenAddress]
        : undefined
    : undefined;

  const { data: amountsOut, isLoading: quoteLoading } = useReadContract({
    address: dexConfig?.routerAddress,
    abi: ROUTER_ABI,
    functionName: 'getAmountsOut',
    args: quotePath ? [parsedPayAmount, quotePath] : undefined,
    query: {
      enabled:
        !!dexConfig &&
        parsedPayAmount > BigInt(0) &&
        !!tokenAddress &&
        !!quotePath,
      refetchInterval: 15000,
      retry: false,
    },
  });

  const quotedBC400   = amountsOut ? (amountsOut as bigint[]).at(-1) : undefined;
  // 5% slippage tolerance (covers buy tax + price movement)
  const amountOutMin  = quotedBC400 ? (quotedBC400 * BigInt(95)) / BigInt(100) : BigInt(0);

  // ── Write contracts ─────────────────────────────────────────

  const { writeContract: approveWrite, data: approveTxHash, isPending: isApproving } = useWriteContract();
  const { isSuccess: approveConfirmed } = useWaitForTransactionReceipt({ hash: approveTxHash });

  const { writeContract: swapWrite, data: swapTxHash, isPending: isSwapping } = useWriteContract();
  const { isSuccess: swapConfirmed } = useWaitForTransactionReceipt({ hash: swapTxHash });

  // Refetch allowance after approval confirms
  useEffect(() => {
    if (approveConfirmed) refetchAllowance();
  }, [approveConfirmed, refetchAllowance]);

  // ── State machine ────────────────────────────────────────────

  useEffect(() => {
    if (!isConnected)  { setState('idle');        return; }
    if (!isSupported)  { setState('unsupported'); return; }
    if (!dexConfig)    { setState('no_dex');      return; }
    if (swapConfirmed) { setState('success');     return; }
    if (isSwapping)    { setState('swapping');    return; }
    if (isApproving)   { setState('approving');   return; }
    setState('ready');
  }, [isConnected, isSupported, dexConfig, swapConfirmed, isSwapping, isApproving]);

  // ── Derived values ───────────────────────────────────────────

  const isApproved =
    selectedToken?.isNative ||
    approveConfirmed ||
    (allowance !== undefined && parsedPayAmount > BigInt(0) && (allowance as bigint) >= parsedPayAmount);

  const needsApproval = !selectedToken?.isNative && !isApproved;
  const step = isApproved ? 2 : 1;

  const payBalance: bigint | undefined = selectedToken?.isNative
    ? nativeBalance?.value
    : (erc20Balance as bigint | undefined);

  // ── Handlers ─────────────────────────────────────────────────

  const handleMax = useCallback(() => {
    if (payBalance === undefined) return;
    const decimals = payTokenDecimals;
    const divisor  = BigInt(10 ** decimals);
    const whole    = payBalance / divisor;
    const frac     = payBalance % divisor;
    const fracStr  = frac.toString().padStart(decimals, '0').replace(/0+$/, '');
    setPayAmount(fracStr ? `${whole}.${fracStr}` : whole.toString());
  }, [payBalance, payTokenDecimals]);

  function handleApprove() {
    if (!selectedToken?.address || !dexConfig) return;
    setError(undefined);
    try {
      approveWrite({
        address: selectedToken.address,
        abi: ERC20_ABI,
        functionName: 'approve',
        args: [dexConfig.routerAddress, parsedPayAmount],
      });
    } catch (e) {
      setError(parseContractError(e));
    }
  }

  function handleBuy() {
    if (!address || !dexConfig || !tokenAddress || amountOutMin === BigInt(0)) return;
    setError(undefined);
    const deadline = BigInt(Math.floor(Date.now() / 1000) + 1200);
    try {
      if (selectedToken?.isNative) {
        swapWrite({
          address: dexConfig.routerAddress,
          abi: ROUTER_ABI,
          functionName: 'swapExactETHForTokensSupportingFeeOnTransferTokens',
          args: [amountOutMin, [dexConfig.wethAddress, tokenAddress], address, deadline],
          value: parsedPayAmount,
        });
      } else if (selectedToken?.address) {
        swapWrite({
          address: dexConfig.routerAddress,
          abi: ROUTER_ABI,
          functionName: 'swapExactTokensForTokensSupportingFeeOnTransferTokens',
          args: [parsedPayAmount, amountOutMin, [selectedToken.address, dexConfig.wethAddress, tokenAddress], address, deadline],
        });
      }
    } catch (e) {
      setError(parseContractError(e));
    }
  }

  // Rate per 1 unit of payment token (in BC400 wei, 18 decimals)
  const rateBC400 =
    quotedBC400 && parsedPayAmount > BigInt(0)
      ? (quotedBC400 * BigInt(10 ** payTokenDecimals)) / parsedPayAmount
      : undefined;

  const explorerUrl = CHAIN_INFO[chainId]?.explorerUrl;

  // ── Render ───────────────────────────────────────────────────

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

        {/* ── Header ── */}
        <div style={{ textAlign: 'center', marginBottom: 'var(--space-6)' }}>
          <h1 style={{ fontSize: '1.5rem', marginBottom: 'var(--space-2)' }}>Buy {TOKEN_SYMBOL}</h1>
          <p style={{ color: 'var(--text-secondary)', fontSize: '0.875rem' }}>
            Purchase {TOKEN_SYMBOL} with any supported token
          </p>
          {isConnected && (
            <div style={{ marginTop: 'var(--space-3)' }}>
              {isSupported ? (
                <span className="badge badge-success" style={{ gap: 6 }}>
                  <span className={`chain-dot ${CHAIN_INFO[chainId]?.dotClass || ''}`} style={{ width: 6, height: 6 }} />
                  {CHAIN_INFO[chainId]?.name}
                  {dexConfig && (
                    <span style={{ opacity: 0.6, fontWeight: 400 }}>· {dexConfig.dexName}</span>
                  )}
                </span>
              ) : (
                <span className="badge badge-error">Unsupported Chain</span>
              )}
            </div>
          )}
        </div>

        {/* ── Not connected ── */}
        {state === 'idle' && (
          <div style={{ textAlign: 'center', padding: 'var(--space-8) 0', color: 'var(--text-secondary)' }}>
            Connect your wallet to buy {TOKEN_SYMBOL}
          </div>
        )}

        {/* ── Unsupported chain ── */}
        {state === 'unsupported' && (
          <div style={{ textAlign: 'center', padding: 'var(--space-8) 0' }}>
            <p style={{ color: 'var(--warning)', marginBottom: 'var(--space-4)', fontSize: '1rem' }}>
              Switch to a supported chain
            </p>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 'var(--space-2)', justifyContent: 'center' }}>
              {(SUPPORTED_CHAIN_IDS as readonly number[]).map(id => (
                <span key={id} className="badge badge-accent" style={{ gap: 6 }}>
                  <span className={`chain-dot ${CHAIN_INFO[id]?.dotClass || ''}`} style={{ width: 6, height: 6 }} />
                  {CHAIN_INFO[id]?.name}
                </span>
              ))}
            </div>
          </div>
        )}

        {/* ── No DEX configured ── */}
        {state === 'no_dex' && (
          <div style={{ textAlign: 'center', padding: 'var(--space-8) 0', color: 'var(--text-secondary)' }}>
            DEX not configured for this chain yet.
          </div>
        )}

        {/* ── Main form ── */}
        {isConnected && isSupported && dexConfig && state !== 'success' && (
          <>
            {/* YOU PAY */}
            <div style={{ marginBottom: 'var(--space-2)' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 'var(--space-2)' }}>
                <span style={{ color: 'var(--text-secondary)', fontSize: '0.8125rem', letterSpacing: '0.05em' }}>YOU PAY</span>
                <span style={{ color: 'var(--text-muted)', fontSize: '0.8125rem' }}>
                  Balance:{' '}
                  <span className="mono">
                    {payBalance !== undefined
                      ? formatTokenAmount(payBalance, payTokenDecimals)
                      : '—'}
                  </span>{' '}
                  <span style={{ color: 'var(--text-secondary)' }}>{selectedToken?.symbol}</span>
                </span>
              </div>

              <div style={{ position: 'relative' }}>
                <input
                  type="text"
                  inputMode="decimal"
                  className="glass-input"
                  placeholder="0.00"
                  value={payAmount}
                  onChange={e => {
                    const v = e.target.value.replace(/[^0-9.]/g, '');
                    if (v.split('.').length <= 2) setPayAmount(v);
                  }}
                  style={{ paddingRight: 148 }}
                />

                <div style={{
                  position: 'absolute', right: 8, top: '50%', transform: 'translateY(-50%)',
                  display: 'flex', alignItems: 'center', gap: 6,
                }}>
                  <button
                    onClick={handleMax}
                    className="glass-btn glass-btn-ghost"
                    style={{ padding: '3px 8px', fontSize: '0.6875rem' }}
                  >
                    MAX
                  </button>

                  {/* Token selector trigger */}
                  <div style={{ position: 'relative' }}>
                    <button
                      onClick={() => setShowTokenSelect(v => !v)}
                      className="glass-btn glass-btn-ghost"
                      style={{ padding: '4px 10px', fontSize: '0.8125rem', gap: 4, minWidth: 80 }}
                    >
                      {selectedToken?.symbol ?? '...'} ▾
                    </button>

                    {/* Dropdown */}
                    {showTokenSelect && (
                      <div style={{
                        position: 'absolute', top: 'calc(100% + 4px)', right: 0, zIndex: 20,
                        minWidth: 180,
                        background: 'rgba(8, 11, 20, 0.98)',
                        border: '1px solid var(--glass-border)',
                        borderRadius: 'var(--radius-md)',
                        overflow: 'hidden',
                        boxShadow: '0 8px 24px rgba(0,0,0,0.5)',
                      }}>
                        {dexConfig.paymentTokens.map(token => (
                          <button
                            key={token.symbol}
                            onClick={() => {
                              setSelectedToken(token);
                              setShowTokenSelect(false);
                              setPayAmount('');
                            }}
                            style={{
                              display: 'flex',
                              alignItems: 'center',
                              justifyContent: 'space-between',
                              width: '100%',
                              padding: 'var(--space-3) var(--space-4)',
                              background: token.symbol === selectedToken?.symbol
                                ? 'var(--accent-dim)' : 'transparent',
                              border: 'none',
                              color: token.symbol === selectedToken?.symbol
                                ? 'var(--accent)' : 'var(--text-primary)',
                              cursor: 'pointer',
                              fontSize: '0.9375rem',
                              textAlign: 'left',
                            }}
                          >
                            <span style={{ fontWeight: 600 }}>{token.symbol}</span>
                            <span style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>{token.name}</span>
                          </button>
                        ))}
                      </div>
                    )}
                  </div>
                </div>
              </div>
            </div>

            {/* Arrow */}
            <div style={{ textAlign: 'center', margin: 'var(--space-3) 0', color: 'var(--text-muted)', fontSize: '1.25rem' }}>
              ↓
            </div>

            {/* YOU RECEIVE */}
            <div style={{ marginBottom: 'var(--space-6)' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 'var(--space-2)' }}>
                <span style={{ color: 'var(--text-secondary)', fontSize: '0.8125rem', letterSpacing: '0.05em' }}>YOU RECEIVE</span>
                <span style={{ color: 'var(--text-muted)', fontSize: '0.8125rem' }}>
                  Balance:{' '}
                  <span className="mono" style={{ color: 'var(--accent)' }}>
                    {formatTokenAmount(bc400Balance as bigint | undefined)}
                  </span>{' '}
                  <span style={{ color: 'var(--text-secondary)' }}>{TOKEN_SYMBOL}</span>
                </span>
              </div>

              <div style={{
                padding: 'var(--space-3) var(--space-4)',
                background: 'rgba(0,0,0,0.5)',
                border: '1px solid var(--glass-border)',
                borderRadius: 'var(--radius-sm)',
                display: 'flex',
                justifyContent: 'space-between',
                alignItems: 'center',
                minHeight: 56,
              }}>
                <span className="mono" style={{
                  fontSize: '1.25rem',
                  color: quotedBC400 ? 'var(--secondary)' : 'var(--text-muted)',
                }}>
                  {quoteLoading
                    ? <span style={{ fontSize: '0.875rem' }}>Fetching price...</span>
                    : quotedBC400
                      ? formatTokenAmount(quotedBC400)
                      : '0.00'}
                </span>
                <span style={{ fontWeight: 700, color: 'var(--accent)', fontSize: '1rem' }}>{TOKEN_SYMBOL}</span>
              </div>
            </div>

            {/* Quote info box */}
            {quotedBC400 && parsedPayAmount > BigInt(0) && (
              <div style={{
                padding: 'var(--space-4)',
                background: 'var(--glass-bg)',
                borderRadius: 'var(--radius-lg)',
                marginBottom: 'var(--space-6)',
                border: '1px solid var(--glass-border)',
              }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 'var(--space-3)' }}>
                  <span style={{ color: 'var(--text-secondary)', fontSize: '0.8125rem' }}>Rate</span>
                  <span className="mono" style={{ fontSize: '0.8125rem' }}>
                    1 {selectedToken?.symbol} ≈ {rateBC400 ? formatTokenAmount(rateBC400) : '—'} {TOKEN_SYMBOL}
                  </span>
                </div>
                <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 'var(--space-3)' }}>
                  <span style={{ color: 'var(--text-secondary)', fontSize: '0.8125rem' }}>Slippage</span>
                  <span style={{ fontSize: '0.8125rem' }}>5%</span>
                </div>
                <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                  <span style={{ color: 'var(--text-secondary)', fontSize: '0.8125rem' }}>Min. Received</span>
                  <span className="mono" style={{ fontSize: '0.8125rem', color: 'var(--accent)' }}>
                    {formatTokenAmount(amountOutMin)} {TOKEN_SYMBOL}
                  </span>
                </div>
              </div>
            )}

            {/* Step indicator — only shown for ERC20 with approve step */}
            {needsApproval && parsedPayAmount > BigInt(0) && (
              <>
                <div className="step-indicator" style={{ justifyContent: 'center', marginBottom: 'var(--space-4)' }}>
                  <div className={`step-dot ${step >= 1 ? (isApproved ? 'step-dot-complete' : 'step-dot-active') : ''}`}>1</div>
                  <div className={`step-line ${isApproved ? 'step-line-active' : ''}`} />
                  <div className={`step-dot ${step >= 2 ? 'step-dot-active' : ''}`}>2</div>
                </div>
                <div style={{ textAlign: 'center', marginBottom: 'var(--space-4)', color: 'var(--text-secondary)', fontSize: '0.8125rem' }}>
                  Step {step} of 2 — {isApproved ? `Buy ${TOKEN_SYMBOL}` : `Approve ${selectedToken?.symbol}`}
                </div>
              </>
            )}

            {/* Action button */}
            {needsApproval && !isApproved ? (
              <button
                className="glass-btn glass-btn-primary"
                style={{ width: '100%', padding: 'var(--space-4)' }}
                disabled={!payAmount || parsedPayAmount === BigInt(0) || isApproving}
                onClick={handleApprove}
              >
                {state === 'approving'
                  ? <><div className="spinner" /> Approving {selectedToken?.symbol}...</>
                  : `Approve ${selectedToken?.symbol}`}
              </button>
            ) : (
              <button
                className="glass-btn glass-btn-primary"
                style={{ width: '100%', padding: 'var(--space-4)' }}
                disabled={!payAmount || parsedPayAmount === BigInt(0) || !quotedBC400 || isSwapping}
                onClick={handleBuy}
              >
                {state === 'swapping'
                  ? <><div className="spinner" /> Buying {TOKEN_SYMBOL}...</>
                  : `Buy ${TOKEN_SYMBOL}`}
              </button>
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

            {/* No liquidity hint */}
            {parsedPayAmount > BigInt(0) && !quoteLoading && !quotedBC400 && !error && (
              <div style={{
                marginTop: 'var(--space-4)',
                padding: 'var(--space-3)',
                background: 'var(--warning-dim)',
                borderRadius: 'var(--radius-md)',
                color: 'var(--warning)',
                fontSize: '0.8125rem',
                textAlign: 'center',
              }}>
                No liquidity pool found. {TOKEN_SYMBOL}/{selectedToken?.symbol} pool may not exist yet on {CHAIN_INFO[chainId]?.name}.
              </div>
            )}
          </>
        )}

        {/* ── Success ── */}
        {state === 'success' && (
          <div className="success-glow" style={{ textAlign: 'center', padding: 'var(--space-6) 0' }}>
            <div style={{ fontSize: '3rem', marginBottom: 'var(--space-4)' }}>✓</div>
            <h2 style={{ color: 'var(--success)', marginBottom: 'var(--space-3)' }}>Purchase Complete!</h2>
            <p style={{ color: 'var(--text-secondary)', marginBottom: 'var(--space-4)' }}>
              {TOKEN_SYMBOL} has been added to your wallet
            </p>
            {swapTxHash && explorerUrl && (
              <a
                href={`${explorerUrl}/tx/${swapTxHash}`}
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
