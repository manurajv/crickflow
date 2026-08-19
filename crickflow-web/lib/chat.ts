export function chatIdFor(a: string, b: string) {
  return [a, b].sort().join("_");
}

export function chatBlockId(blockerId: string, blockedId: string) {
  return `${blockerId}_${blockedId}`;
}
