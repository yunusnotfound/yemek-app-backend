export type Resource = { totalBytes: number; usedBytes: number; percent: number };
export type ContainerMetric = {
  service: string; state: string; health: string; restarts: number; startedAt: string;
  imageId: string; imageCreatedAt: string | null; cpuPercent: number | null;
  memoryUsedBytes: number | null; memoryLimitBytes: number | null; memoryPercent: number | null;
  networkRxBytes: number | null; networkTxBytes: number | null; pids: number | null;
};
export type RuntimeMetrics = {
  startedAt: string; sampledAt: string; uptimeSeconds: number; nodeVersion: string;
  windowSeconds: number; requests: number; requestsPerMinute: number;
  statusCounts: { success: number; clientError: number; serverError: number };
  errorRatePercent: number | null; p50Ms: number | null; p95Ms: number | null; maxMs: number | null;
  inFlight: number; heapUsedBytes: number; heapTotalBytes: number; rssBytes: number;
  eventLoopP95Ms: number | null; eventLoopWindowSeconds: number; droppedSamples: number;
  slowRoutes: { method: string; route: string; requests: number; p95Ms: number; errors: number }[];
};
export type OperationsSnapshot = {
  collectedAt: string; collectionMs: number; source: string; partialErrors: string[];
  host: null | {
    cpuCores: number; cpuPercent: number; loadAverage: number[]; uptimeSeconds: number;
    memory: Resource; swap: Resource; disk: Resource; kernel: string;
    networkRxBytes: number; networkTxBytes: number;
  };
  containers: ContainerMetric[];
  database: null | {
    version: string; sizeBytes: number; connections: number; maxConnections: number;
    activeQueries: number; waitingQueries: number; longestQuerySeconds: number;
    cacheHitPercent: number | null; commits: number; rollbacks: number; deadlocks: number;
    statsReset: string | null; latencyMs: number; lastMigration: string | null;
    tables: { name: string; rows: number; bytes: number }[];
  };
  redis: null | {
    version: string; uptimeSeconds: number; usedMemoryBytes: number; maxMemoryBytes: number;
    fragmentationRatio: number; clients: number; opsPerSecond: number; hitRatePercent: number | null;
    evictedKeys: number; rejectedConnections: number; keyCount: number; blockedClients: number;
    latencyMs: number; aofStatus: string; rdbStatus: string; lastSaveAt: string | null;
  };
  http: {
    api: null | { status: string; httpStatus: number; latencyMs: number; database: string; redis: string; uptimeSeconds: number; paymentMode: string };
    web: null | { httpStatus: number; latencyMs: number };
    tls: null | { expiresAt: string; daysRemaining: number };
  };
  logs: null | {
    windowMinutes: number; sampledLines: number; limited: boolean; errors: number; warnings: number;
    categories: { label: string; count: number; lastAt: string | null }[];
  };
  backups: null | { latestAt: string | null; ageSeconds: number | null; sizeBytes: number | null; count: number };
  release: null | { checkoutSha: string; checkoutAt: string; checkoutDirty: boolean };
  integrations: null | { sentry: boolean; email: boolean; google: boolean; apple: boolean; payments: boolean; paymentMode: string; alloy: string };
  queues: null | { expiredPaymentHolds: number; pendingRefunds: number; staleRefunds: number; heldApprovals: number; awaitingPayment: number };
  runtime: RuntimeMetrics | null;
  runtimeError: string | null;
};
