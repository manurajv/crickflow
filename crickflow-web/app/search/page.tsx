"use client";

import { SearchPanel } from "@/features/search/search-dialog";
import { PageHeader } from "@/components/shared/page-shell";

export default function SearchPage() {
  return (
    <div className="mx-auto max-w-xl">
      <PageHeader
        title="Search"
        eyebrow="Find cricket"
        description="Press Ctrl+K from anywhere, or search players, teams, matches, and more here."
      />
      <SearchPanel autoFocus />
    </div>
  );
}
