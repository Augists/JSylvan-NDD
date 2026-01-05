# Repository Guidelines

## 项目概述
本仓库用于比较不同 Sylvan/Lace 版本组合在 NDD（Java JNI + Sylvan）上的构建与性能表现，并记录 NQueens 基准测试结果。

## 目录结构
- `NDD_sylvan-*/`：各版本变体源码目录（按 Sylvan/Lace 版本命名）。
- `build-variants.sh`：统一构建脚本，支持选择变体与构建开关。
- `NDD_VARIANT_RESULTS.md`：性能结果与分析记录。

## 快速开始
1. 选择变体（示例：bundled191）。
2. 运行构建脚本（MMAP 默认 ON，GMP 可选）：
   - `./build-variants.sh --gmp=off --mmap=on bundled191`
   - `./build-variants.sh --gmp=on --mmap=on bundled191`
3. 运行 NQueens（N=8..12）：
   - `cd NDD_sylvan-1.9.1-lace-bundled`
   - `java -cp target/ndd-1.0.1-jar-with-dependencies.jar application.nqueen.NQueensTest 12`

## 构建脚本说明
`build-variants.sh` 支持以下参数：
- `--gmp=on|off`：是否启用 GMP（仅对支持的 Sylvan 版本生效）。
- `--mmap=on|off`：是否启用 MMAP。
- `--no-clean`：复用已有构建产物，减少重复编译。
- 变体名：如 `bundled141`、`lace142`、`lace150`、`lace151`、`lace203`、`bundled191`。

示例：`./build-variants.sh --no-clean --gmp=off --mmap=on lace151`

## 结果记录与对比
测试结果与分析记录在 `NDD_VARIANT_RESULTS.md`。
