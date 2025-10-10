export function addCSRFToken(headers: Headers): Headers {
  const token = document.cookie
    .split('; ')
    .find(row => row.startsWith('csrf-token='))
    ?.split('=')[1];

  if (token) {
    headers.append('X-CSRF-Token', token);
  }

  return headers;
}