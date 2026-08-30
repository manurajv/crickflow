"use client";

import { useEffect } from "react";

export default function GlobalError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    console.error(error);
  }, [error]);

  return (
    <html lang="en">
      <body className="grid min-h-screen place-items-center bg-[#f4f6f8] p-6 text-[#0f172a]">
        <div className="max-w-md rounded-3xl border border-[#d7dee8] bg-white p-8 text-center shadow-sm">
          <div className="mx-auto mb-4 flex h-14 w-14 items-center justify-center rounded-full bg-[#e3f2fd] text-2xl" aria-hidden>
            🏏
          </div>
          <h1 className="text-2xl font-black">CrickFlow is unavailable</h1>
          <p className="mt-2 text-sm text-[#475569]">A critical error occurred. Please try again.</p>
          <button
            type="button"
            className="mt-6 rounded-xl bg-[#1565c0] px-5 py-2.5 font-semibold text-white hover:bg-[#1565c0]/90"
            onClick={reset}
          >
            Retry
          </button>
        </div>
      </body>
    </html>
  );
}
