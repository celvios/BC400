// Error message mapping for user-friendly display
const ERROR_MESSAGES: Record<string, string> = {
  'MigrationNotActive':          'Migration is currently paused.',
  'MigrationDeadlinePassed':     'The migration window has closed.',
  'MigrationDeadlineNotReached': 'Migration deadline has not been reached yet.',
  'InsufficientNewTokenBalance': 'Migration pool is empty. Contact the team.',
  'ZeroAmount':                  'Please enter an amount greater than 0.',
  'ZeroAddress':                 'Invalid address provided.',
  'NotAdmin':                    'This action requires admin access.',
  'TaxTooHigh':                  'Tax rate exceeds the maximum allowed.',
  'user rejected transaction':   'Transaction cancelled.',
  'User rejected the request':   'Transaction cancelled.',
  'insufficient funds':          'Not enough funds to cover gas fees.',
  'INSUFFICIENT_FUNDS':          'Not enough funds to cover gas fees.',
  'nonce too low':               'Transaction nonce conflict. Please try again.',
  'execution reverted':          'Transaction would fail. Please check your inputs.',
};

export function parseContractError(error: unknown): string {
  if (!error) return 'An unknown error occurred.';

  const errorStr = typeof error === 'string' ? error : 
    (error as { message?: string; shortMessage?: string })?.shortMessage ?? 
    (error as { message?: string })?.message ?? 
    String(error);

  // Check each known error pattern
  for (const [pattern, message] of Object.entries(ERROR_MESSAGES)) {
    if (errorStr.includes(pattern)) {
      return message;
    }
  }

  // Generic fallback — never show raw error to user
  if (errorStr.includes('revert')) {
    return 'Transaction failed. Please try again or contact support.';
  }

  return 'Something went wrong. Please try again.';
}
