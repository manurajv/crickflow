import { getDownloadURL, ref, uploadBytes } from "firebase/storage";
import { getFirebaseStorage } from "@/lib/firebase/client";

export const COMMUNITY_IMAGE_MAX_BYTES = 5 * 1024 * 1024;
export const PROFILE_IMAGE_MAX_BYTES = 2 * 1024 * 1024;
export const MAX_POST_PHOTOS = 4;

export function communityImagePath(userId: string, stamp: number) {
  return `community/${userId}/${stamp}.jpg`;
}

export function opportunityImagePath(userId: string, stamp: number) {
  return `opportunities/${userId}/${stamp}.jpg`;
}

export function userProfileImagePath(userId: string) {
  return `users/${userId}/profile.jpg`;
}

export function storageUploadHint(error: unknown) {
  const message = error instanceof Error ? error.message : String(error);
  if (/cors|network|failed to fetch|err_failed/i.test(message)) {
    return "Photo upload is blocked by Storage CORS. Images still work when posted from the app.";
  }
  if (/unauthorized|permission|storage\/unauthorized/i.test(message)) {
    return "Could not upload this photo. Sign in and use a JPEG under the size limit.";
  }
  return message || "Could not upload photo";
}

export async function fileToJpegBlob(file: File, maxBytes: number): Promise<Blob> {
  if (typeof createImageBitmap !== "function") {
    if (file.type === "image/jpeg" && file.size <= maxBytes) return file;
    throw new Error("This browser cannot convert photos. Use a JPEG under 5 MB.");
  }
  const bitmap = await createImageBitmap(file);
  const maxDim = 1920;
  const scale = Math.min(1, maxDim / Math.max(bitmap.width, bitmap.height));
  const width = Math.max(1, Math.round(bitmap.width * scale));
  const height = Math.max(1, Math.round(bitmap.height * scale));
  const canvas = document.createElement("canvas");
  canvas.width = width;
  canvas.height = height;
  const ctx = canvas.getContext("2d");
  if (!ctx) {
    bitmap.close();
    throw new Error("Could not process image");
  }
  ctx.drawImage(bitmap, 0, 0, width, height);
  bitmap.close();
  let quality = 0.88;
  for (let i = 0; i < 6; i += 1) {
    const blob = await new Promise<Blob | null>((resolve) => canvas.toBlob(resolve, "image/jpeg", quality));
    if (blob && blob.size <= maxBytes) return blob;
    quality -= 0.12;
  }
  throw new Error("Image is too large. Choose a smaller photo.");
}

async function uploadJpeg(path: string, file: File, maxBytes: number) {
  const blob = await fileToJpegBlob(file, maxBytes);
  const storageRef = ref(getFirebaseStorage(), path);
  await uploadBytes(storageRef, blob, { contentType: "image/jpeg" });
  return getDownloadURL(storageRef);
}

export async function uploadCommunityImages(userId: string, files: File[]) {
  const urls: string[] = [];
  const chosen = files.slice(0, MAX_POST_PHOTOS);
  for (const [index, file] of chosen.entries()) {
    urls.push(await uploadJpeg(communityImagePath(userId, Date.now() + index), file, COMMUNITY_IMAGE_MAX_BYTES));
  }
  return urls;
}

export async function uploadOpportunityImages(userId: string, files: File[]) {
  const urls: string[] = [];
  const chosen = files.slice(0, MAX_POST_PHOTOS);
  for (const [index, file] of chosen.entries()) {
    urls.push(await uploadJpeg(opportunityImagePath(userId, Date.now() + index), file, COMMUNITY_IMAGE_MAX_BYTES));
  }
  return urls;
}

export async function uploadUserProfilePhoto(userId: string, file: File) {
  return uploadJpeg(userProfileImagePath(userId), file, PROFILE_IMAGE_MAX_BYTES);
}

export const SERIES_IMAGE_MAX_BYTES = 5 * 1024 * 1024;

export function seriesLogoPath(seriesId: string, userId: string) {
  return `series/${seriesId}/logo_${userId}.jpg`;
}

export function seriesCoverPath(seriesId: string, userId: string) {
  return `series/${seriesId}/cover_${userId}.jpg`;
}

export function seriesRegistrationImagePath(
  seriesId: string,
  userId: string,
  kind: "photo" | "doc",
) {
  const stamp = Date.now();
  return `series/${seriesId}/${kind}_${userId}_${stamp}.jpg`;
}

export async function uploadSeriesLogo(seriesId: string, userId: string, file: File) {
  return uploadJpeg(seriesLogoPath(seriesId, userId), file, SERIES_IMAGE_MAX_BYTES);
}

export async function uploadSeriesCover(seriesId: string, userId: string, file: File) {
  return uploadJpeg(seriesCoverPath(seriesId, userId), file, SERIES_IMAGE_MAX_BYTES);
}

export async function uploadSeriesRegistrationImage(
  seriesId: string,
  userId: string,
  file: File,
  kind: "photo" | "doc" = "photo",
) {
  return uploadJpeg(seriesRegistrationImagePath(seriesId, userId, kind), file, SERIES_IMAGE_MAX_BYTES);
}
