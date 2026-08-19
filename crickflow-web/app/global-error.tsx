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
      <body className="grid min-h-screen place-items-center bg-[#0a0e17] p-6 text-white">
        <div className="max-w-md text-center">
          <h1 className="text-2xl font-bold">CrickFlow is unavailable</h1>
          <p className="mt-2 text-sm text-white/70">A critical error occurred. Please try again.</p>
          <button
            type="button"
            className="mt-6 rounded-xl bg-[#1e88e5] px-4 py-2 font-semibold"
            onClick={reset}
          >
            Retry
          </button>
        </div>
      </body>
    </html>
  );
}
