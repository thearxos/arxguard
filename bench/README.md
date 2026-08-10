# Native performance benchmark

Build the C engine with release optimization, then run `native_bench` on an otherwise idle machine. Record CPU model, compiler, optimization flags, OS/kernel, and whether the benchmark is pinned to a CPU.

The benchmark reports nanoseconds per scan for a clean command and a known dangerous command over 1,000,000 iterations. These are measurements, not guaranteed latency targets; report p50/p95/p99 separately for shell-hook end-to-end latency.
