# ADR-001: Built-in Telemetry with OpenTelemetry

## Status

Accepted

## Context

Vaisto targets cloud developers who expect observability out of the box. In typical cloud stacks (Go, Rust, Node), developers must:

1. Choose an observability library
2. Add dependencies
3. Manually instrument code
4. Configure exporters
5. Wire up endpoints

This creates friction and leads to services running blind in production.

The BEAM runtime already tracks extensive telemetry internally:
- Process counts and memory per process
- Message queue depths
- Scheduler utilization
- Garbage collection stats
- Reductions (CPU proxy)
- IO throughput

Competing BEAM languages (Elixir, Gleam) expose this via optional libraries, requiring explicit setup.

## Decision

Vaisto will have **built-in telemetry** with the following design:

### 1. Collection is always on

The runtime automatically collects:
- BEAM VM metrics (processes, memory, schedulers, GC, IO)
- Process lifecycle events (spawn, exit, crash)
- Message passing traces (sender, receiver, message type)
- User-defined metrics via `emit`

This has negligible overhead — the BEAM already tracks most of this.

### 2. OpenTelemetry as the interchange format

OTEL is the export format, not a vendor choice. OTEL supports:
- Prometheus
- Jaeger / Zipkin
- Datadog
- Honeycomb
- Splunk
- AWS X-Ray
- Google Cloud Trace
- Grafana stack
- Any OTLP-compatible backend

This gives users freedom without Vaisto maintaining multiple exporters.

### 3. Export is configurable

Export destination is configured via environment variables, not code:

```bash
# OTLP export (default)
VAISTO_TELEMETRY=otlp
VAISTO_TELEMETRY_ENDPOINT=https://collector:4317

# JSON to stdout (for custom pipelines)
VAISTO_TELEMETRY=json

# Disabled (dev mode)
VAISTO_TELEMETRY=off
```

Default: `otlp` with no endpoint (collection active, export inactive until configured).

### 4. Automatic instrumentation

The compiler/runtime instruments automatically:
- Every `spawn` creates a trace span
- Every `!` (message send) links spans
- Every `process` handler is a span
- HTTP handlers (via `httpd`) get request/response spans

Users write zero instrumentation code. The trace graph mirrors the process graph.

### 5. User-defined metrics

Simple API for custom metrics:

```scheme
(emit :request_count 1)
(emit :request_duration_ms elapsed)
(emit :queue_depth (length queue) {:queue_name name})
```

## Consequences

### Positive

- Zero-config observability for cloud deployments
- Differentiator vs Elixir/Gleam ("observable by default")
- BEAM's introspection becomes a visible feature, not hidden capability
- Distributed tracing "just works" across process boundaries
- DevOps configures export target, developers don't touch observability code

### Negative

- Small runtime overhead (mitigated: BEAM already collects most data)
- Opinionated — users who want different tracing semantics can't opt out of collection
- OTEL dependency in runtime

### Neutral

- Users can disable export but not collection
- No Prometheus-native export (use OTEL->Prometheus pipeline)

## Alternatives Considered

### A. Telemetry as optional package

Rejected. Makes observability opt-in, which means:
- Developers skip it under deadline pressure
- "Add telemetry" becomes a PR/review/decision
- Our differentiator disappears

### B. Prometheus-native instead of OTEL

Rejected. Prometheus is metrics-only. OTEL covers traces, metrics, and logs with one protocol. OTEL can export to Prometheus anyway.

### C. Multiple export formats maintained by Vaisto

Rejected. Maintenance burden. OTEL already solved the "export to everything" problem.

## References

- [OpenTelemetry specification](https://opentelemetry.io/docs/specs/otel/)
- [opentelemetry-erlang](https://github.com/open-telemetry/opentelemetry-erlang)
- [BEAM introspection via erlang module](https://www.erlang.org/doc/man/erlang.html)
