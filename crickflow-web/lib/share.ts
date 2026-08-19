"use client";

export async function shareEntity(title: string, path: string) {
  const url = `${window.location.origin}${path}`;
  try {
    if (navigator.share) {
      await navigator.share({ title, url });
      return false;
    }
  } catch {
    /* user cancelled or share failed — fall through to copy */
  }
  await navigator.clipboard.writeText(url);
  return true;
}
