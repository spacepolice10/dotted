export function debounce(callback, delayMs) {
  let timeoutId = null

  return (...args) => {
    if (timeoutId) clearTimeout(timeoutId)
    timeoutId = setTimeout(() => callback(...args), delayMs)
  }
}
