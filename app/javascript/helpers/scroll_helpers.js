// Scroll primitives for timeline-style lists, where content grows at both ends.

export function scrollToBottom(container, behavior = "instant") {
  container.scrollTo({ top: container.scrollHeight, behavior })
}

// Prepending pushes everything down by the height of the new rows. Restoring the
// distance to the bottom edge leaves the row the reader was looking at exactly
// where it was.
export function keepScroll(container, mutate) {
  const anchor = container.scrollHeight - container.scrollTop
  mutate()
  container.scrollTop = container.scrollHeight - anchor
}

// iOS keeps applying momentum after a touch ends and overrides scrollTop writes
// while it does. Clamping overflow for a frame cancels the inertia first.
export function pauseInertiaScroll(container) {
  const previous = container.style.overflowY
  container.style.overflowY = "hidden"
  requestAnimationFrame(() => {
    container.style.overflowY = previous
  })
}
