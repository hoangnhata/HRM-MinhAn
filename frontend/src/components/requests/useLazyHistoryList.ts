import { useCallback, useEffect, useRef, useState } from 'react';
import {
  currentMonthRequestFilters,
  EMPTY_REQUEST_FILTERS,
  type RequestListFilterState,
} from './RequestListFilters';

type HistoryDateRange = { fromDate?: string; toDate?: string };

type Options<T> = {
  /** true khi tab đang chọn là Lịch sử */
  historyActive: boolean;
  canLoad: boolean;
  loadPending: () => Promise<T[]>;
  loadHistory: (range: HistoryDateRange) => Promise<T[]>;
};

/**
 * Chờ duyệt load ngay; Lịch sử chỉ gọi API khi vào tab,
 * mặc định lọc tháng hiện tại (đổi ngày → gọi lại API).
 */
export function useLazyHistoryList<T>({
  historyActive,
  canLoad,
  loadPending,
  loadHistory,
}: Options<T>) {
  const [pending, setPending] = useState<T[]>([]);
  const [history, setHistory] = useState<T[]>([]);
  const [listLoading, setListLoading] = useState(false);
  const [historyLoaded, setHistoryLoaded] = useState(false);
  const [filters, setFilters] = useState<RequestListFilterState>(EMPTY_REQUEST_FILTERS);
  const historyReq = useRef(0);

  const reloadPending = useCallback(() => {
    if (!canLoad) return;
    setListLoading(true);
    loadPending()
      .then(setPending)
      .catch(() => setPending([]))
      .finally(() => setListLoading(false));
  }, [canLoad, loadPending]);

  const reloadHistory = useCallback(
    (nextFilters: RequestListFilterState) => {
      if (!canLoad) return;
      const reqId = ++historyReq.current;
      setListLoading(true);
      loadHistory({
        fromDate: nextFilters.dateFrom || undefined,
        toDate: nextFilters.dateTo || undefined,
      })
        .then((rows) => {
          if (historyReq.current !== reqId) return;
          setHistory(rows);
          setHistoryLoaded(true);
        })
        .catch(() => {
          if (historyReq.current !== reqId) return;
          setHistory([]);
          setHistoryLoaded(true);
        })
        .finally(() => {
          if (historyReq.current === reqId) setListLoading(false);
        });
    },
    [canLoad, loadHistory],
  );

  useEffect(() => {
    if (!canLoad) return;
    reloadPending();
  }, [canLoad, reloadPending]);

  useEffect(() => {
    if (!canLoad) return;
    if (historyActive) {
      const month = currentMonthRequestFilters();
      setFilters(month);
      reloadHistory(month);
    } else {
      setFilters(EMPTY_REQUEST_FILTERS);
    }
    // Chỉ khi đổi tab / quyền — không phụ thuộc filters
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [historyActive, canLoad]);

  const onFiltersChange = useCallback(
    (next: RequestListFilterState) => {
      const dateChanged =
        next.dateFrom !== filters.dateFrom || next.dateTo !== filters.dateTo;
      setFilters(next);
      if (historyActive && dateChanged) {
        reloadHistory(next);
      }
    },
    [filters.dateFrom, filters.dateTo, historyActive, reloadHistory],
  );

  const reload = useCallback(() => {
    reloadPending();
    if (historyActive) {
      reloadHistory(filters);
    }
  }, [reloadPending, historyActive, reloadHistory, filters]);

  return {
    pending,
    setPending,
    history,
    setHistory,
    listLoading,
    historyLoaded,
    filters,
    setFilters: onFiltersChange,
    filterReset: historyActive ? currentMonthRequestFilters() : EMPTY_REQUEST_FILTERS,
    clearLabel: historyActive ? 'Về tháng này' : 'Xóa lọc',
    reload,
    reloadPending,
    reloadHistory: () => reloadHistory(filters),
  };
}
