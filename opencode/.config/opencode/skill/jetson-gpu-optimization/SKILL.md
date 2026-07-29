---
name: jetson-gpu-optimization
description: NVIDIA Jetson and CUDA optimization reference — TensorRT engine building, GPU memory management, kernel optimization, and profiling on edge devices. Use when optimizing inference performance, building TensorRT engines, or profiling GPU code on Jetson.
---

# Jetson GPU Optimization

## When to Load

- Converting models to TensorRT for Jetson deployment
- Optimizing CUDA kernels for Jetson
- Profiling GPU performance on edge devices
- Configuring Jetson power modes
- Diagnosing GPU memory bandwidth bottlenecks

## Core Principles

1. **Memory is King.** On Jetson, CPU and GPU share physical memory. Focus on memory alignment, zero-copy buffers, and eliminating host-to-device transfers. The memory controller is the primary bottleneck for most perception workloads.

2. **Kernel Efficiency.** Optimize CUDA kernels for maximum occupancy and minimal divergence. Every unnecessary register or uncoalesced access costs FPS.

3. **TensorRT Mastery.** Use the best quantization (FP16, INT8) and optimize engines for the specific target hardware. A Jetson Orin engine is NOT portable to a Jetson Xavier.

4. **Measure, Don't Guess.** Every optimization claim must be backed by a benchmark. Use `tegrastats`, Nsight Systems, and CUDA events — never eyeball.

## Profiling Workflow

```bash
# 1. Identify bottleneck
tegrastats --interval 1000
# Look at: GPU%, EMC% (memory), CPU%, power draw

# 2. Nsight Systems trace
nsys profile -t cuda,nvtx,osrt --stats=true ./your_node

# 3. CUDA events for kernel-level timing
# (in code)
cudaEventRecord(start, stream);
// kernel launch
cudaEventRecord(stop, stream);
cudaEventSynchronize(stop);
cudaEventElapsedTime(&ms, start, stop);
```

## Jetson Power Modes

```bash
# Check available modes
sudo nvpmodel -q

# Set performance mode (e.g., Orin)
sudo nvpmodel -m 0   # Max performance
sudo nvpmodel -m 1   # Mode 1 (lower power)

# Lock clocks at max
sudo jetson_clocks

# Unlock (allow dynamic frequency scaling)
sudo jetson_clocks --fan
```

**Always report the power mode with performance numbers.** 15W vs 30W vs 50W gives fundamentally different results.

## TensorRT Quantization Guide

| Precision | Build Flag | Speedup | Calibration | When to Use |
|-----------|-----------|---------|-------------|-------------|
| FP32 | (default) | 1x | None | Debugging, validation |
| FP16 | `--fp16` | 2-3x | None | Production default |
| INT8 | `--int8` | 3-5x | Required | Max throughput with representative data |

### INT8 Calibration
```python
# Calibration requires representative data
# Use actual deployment data distribution, not random data
class Calibrator(trt.IInt8EntropyCalibrator2):
    def __init__(self, calibration_data, batch_size=8, cache_file="calib.cache"):
        self.cache_file = cache_file
        self.data = calibration_data  # np arrays from real data
        self.batch_size = batch_size
        self.current_idx = 0

    def get_batch(self, names):
        if self.current_idx + self.batch_size > len(self.data):
            return None
        batch = self.data[self.current_idx:self.current_idx + self.batch_size]
        self.current_idx += self.batch_size
        return np.ascontiguousarray(batch)
```

## Common Pitfalls

- **Don't mix FP16 and FP32 tensors without explicit casts.** Silent precision mismatches cause incorrect results.
- **Never profile on x86 and assume same bottlenecks on Jetson.** Memory bandwidth, SM count, and cache hierarchy are fundamentally different. Always profile on target device.
- **TensorRT engines are hardware-specific.** Orin engine ≠ Xavier engine. Build on target or specify correct DLACore.
- **Many small kernels < one fused kernel.** Use CUDA graphs for repeated kernel sequences.
- **Jetson power modes affect everything.** Always specify which mode you're using.
- **INT8 calibration data must be representative.** Calibrating on a different distribution than deployment causes accuracy regression.

## Jetson Memory Optimization

```cpp
// Zero-copy mapped memory (Jetson-specific)
void* host_ptr;
cudaHostAlloc(&host_ptr, size, cudaHostAllocMapped);
// host_ptr is directly accessible from GPU — no cudaMemcpy needed

// For discrete GPUs (x86 + RTX), this doesn't work the same way
// Use pinned memory + async copy instead
```

## Benchmarking Protocol

1. Set power mode: `sudo nvpmodel -m 0 && sudo jetson_clocks`
2. Warm up: run 100+ iterations before measuring
3. Measure: 1000+ iterations, record median + p95 + p99
4. Report: model, precision, image size, batch size, FPS, latency (median/p95/p99), power mode, GPU%/EMC%