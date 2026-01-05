# NDD Variant Run Results

## Run Context
- Command: `java -cp target/ndd-1.0.1-jar-with-dependencies.jar application.nqueen.NQueensTest N` (N = 8..12)
- Build flags: `SYLVAN_USE_MMAP=ON`; `SYLVAN_GMP=OFF` and `SYLVAN_GMP=ON` were tested.
- Variants: Sylvan 1.4.1 (bundled Lace), Sylvan 1.8.1 + Lace 1.4.2, Sylvan 1.9.1 + Lace 1.5.0, Sylvan 1.9.1 + Lace 1.5.1, Sylvan 1.9.1 + bundled Lace 1.4.1. Sylvan 1.9.1 + Lace 2.0.3 does not compile due to Lace API macro changes.
- Note: Single run per N; JVM warm-up and OS scheduling can affect timing.

## Results (MMAP=ON, GMP=OFF)

| N | Solutions | NDD Nodes | Time Sylvan 1.4.1 + bundled Lace (s) | Time Sylvan 1.8.1 + Lace 1.4.2 (s) | Time Sylvan 1.9.1 + Lace 1.5.0 (s) | Time Sylvan 1.9.1 + Lace 1.5.1 (s) | Time Sylvan 1.9.1 + bundled Lace (s) |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 8 | 92.0 | 10325 | 0.213 | 0.559 | 0.470 | 0.434 | 0.221 |
| 9 | 352.0 | 28537 | 0.645 | 1.629 | 1.355 | 1.212 | 0.483 |
| 10 | 724.0 | 95707 | 0.903 | 5.390 | 3.843 | 3.126 | 0.886 |
| 11 | 2680.0 | 394639 | 3.329 | 24.101 | 16.309 | 14.509 | 2.846 |
| 12 | 14200.0 | 1851150 | 15.588 | 126.325 | 80.222 | 71.219 | 13.807 |

## Results (MMAP=ON, GMP=ON)

| N | Solutions | NDD Nodes | Time Sylvan 1.4.1 + bundled Lace (s) | Time Sylvan 1.8.1 + Lace 1.4.2 (s) | Time Sylvan 1.9.1 + Lace 1.5.0 (s) | Time Sylvan 1.9.1 + Lace 1.5.1 (s) | Time Sylvan 1.9.1 + bundled Lace (s) |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 8 | 92.0 | 10325 | 0.221 | 0.514 | 0.456 | 0.450 | 0.305 |
| 9 | 352.0 | 28537 | 0.316 | 1.648 | 1.300 | 1.238 | 0.583 |
| 10 | 724.0 | 95707 | 1.052 | 5.558 | 3.812 | 3.509 | 1.095 |
| 11 | 2680.0 | 394639 | 3.394 | 24.223 | 15.358 | 14.592 | 2.809 |
| 12 | 14200.0 | 1851150 | 15.979 | 124.012 | 79.331 | 73.209 | 14.17 |

## Analysis

### 结果一致性
- 所有版本的解数量与节点数一致，说明 Java 层 NDD 逻辑与变量顺序没有改变，性能差异主要来自 Sylvan/Lace 的实现与构建方式。

### 版本差异（按组合说明）
- 1.4.1（bundled Lace）
  - Lace 作为 Sylvan 内置源码存在于同一仓库，编译链条最短。
  - 该版本 CMake 并不识别 `SYLVAN_GMP`/`SYLVAN_USE_MMAP`，所以 GMP/MMAP 的开关不会影响 1.4.1 的性能。
- 1.8.1 + Lace 1.4.2
  - Lace 从 Sylvan 仓库内移出，改为由 CMake FetchContent 拉取外部依赖。
  - Lace 在 1.7/1.8 时期引入 C11 原子与跨平台兼容调整，调度/原子操作的开销更显著。
  - Sylvan 自身增加了新的 hash/align 相关模块，并调整缓存/内存布局实现，这些变化会改变 cache 命中与内存访问模式。
- 1.9.1 + Lace 1.5.0 / 1.5.1
  - Lace 1.5.x 在调度和内部实现上继续迭代，整体比 1.8.1 有明显回升，但仍慢于 1.4.1。
  - Lace 1.5.1 不再在 `lace.h` 里定义 `LINE_SIZE`，需要显式编译参数 `-DLINE_SIZE=64`（已由 `build-variants.sh` 处理）。
  - 实测 1.5.1 比 1.5.0 稍快（N>=10 时大约 5-10%）。
- 1.9.1 + Lace 2.0.3
  - Lace 2.x 引入宏与 API 变更（例如 `VOID_TASK_DECL_*` 与 `gc_hook` 签名），当前无法与 Sylvan 1.9.1 直接编译通过。
- 1.9.1 + bundled Lace 1.4.1（已实现）
  - 兼容点主要在 Sylvan 侧：用 `lace_init` + `lace_startup`/`lace_exit` 取代 `lace_start`/`lace_stop`，`lace_is_worker()` 由 `lace_get_worker()` 衍生替代。
  - Lace 1.4.1 依赖 `WRAP/TOGETHER` 的线程局部变量，Sylvan 1.9.1 新增的调用点需要通过 `RUN`/`TOGETHER` 包装注入 `LACE_ME`，避免在非 worker 线程调用宏时崩溃。
  - Sylvan 1.9.1 的 CMake 依赖外部 Lace，需改为直接编译 `lace.c`/`lace.h`，并补齐 `stdatomic.h` 头文件到相关模块（如 refs/skiplist）。
  - 性能上，该组合在 N>=10 时接近或优于 1.4.1，说明 Sylvan 1.9.1 的内部优化在保留旧 Lace 调度特性时仍有收益。

### 为什么新版本会更慢（基于观察的合理解释）
- 外置 Lace + C11 原子带来的同步成本更高：NQueens 是大量细粒度 BDD 操作，小任务频繁触发调度与原子更新，调度开销更容易成为瓶颈。
- Sylvan 1.8+ 的 hash/align/缓存实现调整会改变内存布局与访问模式，可能降低局部性，导致更多缓存未命中。
- 默认调度参数与线程协作策略在 Lace 版本迭代中变化，但这些变化对“很多小操作”的负载不一定有利。

### 版本选择建议（是否优先用 1.4.1）
- 若你的项目负载与 NQueens 类似（大量小操作、极度依赖调度与缓存），可以优先考虑 1.9.1 + bundled Lace 1.4.1 作为新的基线，再用 1.4.1 做回归对照。
- 若需要新版本的编译器兼容性、平台支持或上游修复，但不想引入外置 Lace 的调度成本，1.9.1 + bundled Lace 1.4.1 是一个折中方案；若坚持上游原生组合，则以 1.9.1 + Lace 1.5.1 为主。
- 当前结果为单次运行，建议每个 N 重复 3-5 次取平均，以减少 JVM 与系统噪声带来的偏差。
