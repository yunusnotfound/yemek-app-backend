"use client";

import { useEffect, useState } from "react";
import type { Paginated } from "@/lib/types";

/** Keeps each list on the server's current page and ignores superseded requests. */
export function usePaginatedList<T>(loadPage: (page: number) => Promise<Paginated<T>>) {
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [items, setItems] = useState<T[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [revision, setRevision] = useState(0);

  useEffect(() => {
    let current = true;
    setItems(null);
    setError(null);
    loadPage(page)
      .then((res) => {
        if (!current) return;
        const lastPage = Math.max(1, res.pagination.totalPages);
        setTotalPages(lastPage);
        // A deletion may remove the last item on the final page.
        if (page > lastPage) {
          setPage(lastPage);
          return;
        }
        setItems(res.data);
      })
      .catch((e) => {
        if (current) setError(e instanceof Error ? e.message : "Yüklenemedi");
      });
    return () => { current = false; };
  }, [loadPage, page, revision]);

  return {
    items,
    error,
    page,
    totalPages,
    setPage,
    reload: () => setRevision((value) => value + 1),
  };
}
