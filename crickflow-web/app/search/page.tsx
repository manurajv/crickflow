"use client";

import { SearchPanel } from "@/features/search/search-dialog";

export default function SearchPage() {
  return (
    <div className="mx-auto max-w-xl">
      <h1 className="text-3xl font-bold">Search</h1>
      <p className="mt-2 mb-4 text-sm text-muted-foreground">
        Press Ctrl+K from anywhere, or search here.
      </p>
      <SearchPanel autoFocus />
    </div>
  );
}
