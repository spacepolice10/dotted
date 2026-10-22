export function navigateCombobox(currentPosition, direction, length) {
  if (length == 0) return -1;
  if (direction == "down") return Math.min(currentPosition + 1, length - 1);
  if (direction == "up") return Math.max(currentPosition - 1, -1);
  return currentPosition;
}
