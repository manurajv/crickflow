export function shellParams<K extends string>(key: K): Array<Record<K, string>> {
  return [{ [key]: "_" } as Record<K, string>];
}
