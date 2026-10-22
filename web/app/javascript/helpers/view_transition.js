export function swapWithViewTransition(update) {
  if (document.startViewTransition && !matchMedia("(prefers-reduced-motion: reduce)").matches) {
    return document.startViewTransition(update)
  }
  update()
}
