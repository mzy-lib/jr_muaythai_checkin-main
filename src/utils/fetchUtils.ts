// Retry mechanism for failed requests
export async function retryWithBackoff<T>(
  operation: () => Promise<T>,
  maxRetries: number = 3,
  initialDelay: number = 1000,
  maxDelay: number = 5000
): Promise<T> {
  let lastError: Error;
  
  for (let i = 0; i < maxRetries; i++) {
    try {
      return await operation();
    } catch (error) {
      lastError = error as Error;
      
      // Don't retry if it's not a network error
      if (!isNetworkError(error)) {
        throw error;
      }
      
      if (i === maxRetries - 1) break;
      
      // Exponential backoff with jitter
      const delay = Math.min(initialDelay * Math.pow(2, i), maxDelay);
      const jitter = Math.random() * 200;
      await new Promise(resolve => setTimeout(resolve, delay + jitter));
    }
  }
  
  throw new Error('网络连接错误，请检查网络后重试。Network connection error, please check your connection and try again.');
}

// Network error detection
function isNetworkError(error: any): boolean {
  return (
    error.message === 'Failed to fetch' ||
    error.message === 'Network request failed' ||
    error instanceof TypeError ||
    error.name === 'AbortError' ||
    error.name === 'NetworkError'
  );
}

// Error handler for Supabase operations
export function handleSupabaseError(error: unknown): string {
  if (error instanceof Error) {
    if (isNetworkError(error)) {
      return '网络连接错误，请检查网络后重试。Network connection error, please check your connection and try again.';
    }
    return error.message;
  }
  return '未知错误，请重试。Unknown error, please try again.';
}