// Returns the new position after moving in a grid with a given number of columns.
// Clamps at grid boundaries — does not wrap.
export function navigateGrid(currentPosition, direction, columns, elements) {
  const directions = { left: -1, right: 1, up: -columns, down: columns };
  const next = currentPosition + directions[direction];
  if (next < 0 || next >= elements) return currentPosition;
  return next;
}
