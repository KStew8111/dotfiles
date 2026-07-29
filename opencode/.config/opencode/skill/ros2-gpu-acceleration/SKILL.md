---
name: ros2-gpu-acceleration
description: Reference for GPU acceleration, TensorRT inference, and CUDA preprocessing in ROS 2 vision pipelines. Use when writing inference nodes, converting models to TensorRT, or optimizing for Jetson.
---

# ROS 2 GPU Acceleration for Vision

## When to Load

- Writing TensorRT inference nodes for ROS 2
- Converting PyTorch/ONNX models to TensorRT engines
- Implementing CUDA-accelerated preprocessing
- Evaluating Isaac ROS NITROS pipeline
- Profiling GPU bottlenecks on Jetson

## TensorRT Engine Building

### Conversion Pipeline
```
PyTorch (.ckpt/.pt) → ONNX (.onnx) → TensorRT (.engine)
```

### Build Commands
```bash
# Export ONNX from PyTorch
python export.py --checkpoint model.ckpt --output model.onnx --opset 18

# Build TensorRT engine (on target device!)
trtexec --onnx=model.onnx --saveEngine=model.engine --fp16
# For INT8 (needs calibration data):
trtexec --onnx=model.onnx --saveEngine=model_int8.engine --int8 --calib=calib.cache
```

**Critical:** Build engines on the target device. A Jetson Orin engine will NOT run on Jetson Xavier. Always specify the correct DLACore.

### Precision Trade-offs
| Precision | Speedup vs FP32 | Accuracy Impact | When to Use |
|-----------|----------------|-----------------|-------------|
| FP32 | 1x | Baseline | Debugging, validation |
| FP16 | 2-3x | Negligible | Default for production |
| INT8 | 3-5x | Requires calibration | Max throughput, have representative data |

## GPU Memory Management

**The #1 sin:** GPU→CPU→GPU round-trips. If rectify outputs to CPU and inference copies back to GPU, you're wasting bandwidth.

### Jetson-specific (shared CPU/GPU memory)
- CPU and GPU share physical memory — zero-copy buffers are natural
- Use `cudaHostAlloc` with `cudaHostAllocMapped` for zero-copy mapped memory
- Memory controller is the primary bottleneck, not compute

### Discrete GPU (x86 + RTX)
- Explicit `cudaMemcpy(DeviceToDevice)` vs `cudaMemcpy(HostToDevice)`
- Minimize host-device transfers; keep data on GPU through entire pipeline
- Use CUDA streams for async transfer/compute overlap

## CUDA-Accelerated Preprocessing

Keep resize, color conversion, and normalization on GPU:

```cpp
// Use cv::cuda (OpenCV CUDA) or NVIDIA VPI
cv::cuda::GpuMat gpu_image = cv::cuda::GpuMat(raw_image);
cv::cuda::GpuMat resized;
cv::cuda::resize(gpu_image, resized, cv::Size(512, 512));

// Normalize on GPU
cv::cuda::GpuMat normalized;
gpu_image.convertTo(normalized, CV_32FC3, 1.0/255.0);
// Subtract mean, divide std on GPU...
```

## Isaac ROS NITROS Pipeline

NVIDIA Isaac ROS provides hardware-accelerated GEMs that chain with zero-copy GPU memory passing:
- Image stays on GPU memory through rectify → resize → inference
- No CPU round-trips between nodes
- Compatible with standard ROS 2 nodes

**Key packages:**
- `isaac_ros_image_pipeline`: rectify, resize, format conversion on GPU
- `isaac_ros_dnn_inference`: TensorRT inference nodes
- `isaac_ros_proximity_segmentation`: ready-made segmentation pipeline

**Repo:** https://github.com/NVIDIA-ISAAC-ROS

## Ready-Made Inference Nodes

**`dusty-nv/ros_deep_learning`**: TensorRT inference nodes for ROS 2 on Jetson
- Image classification, detection, segmentation
- Drop-in `imagenet`, `detectnet`, `segnet` nodes

## Profiling

```bash
# Jetson system stats
tegrastats --interval 1000

# Nsight Systems trace
nsys profile -t cuda,nvtx,osrt --stats=true ./your_node

# CUDA events in code
cudaEventRecord(start, stream);
// ... kernel launch ...
cudaEventRecord(stop, stream);
cudaEventSynchronize(stop);
cudaEventElapsedTime(&ms, start, stop);
```

**Always report:** median + p95 + p99 latency, power mode (15W/30W/50W), and which Jetson model.

## Common Pitfalls

- Don't mix FP16 and FP32 tensors without explicit casts — silent precision mismatches
- Never profile on x86 and assume same bottlenecks on Jetson
- INT8 calibration data must be representative of deployment data distribution
- Many small CUDA kernels are worse than one fused kernel — use CUDA graphs
- Jetson power modes affect performance numbers — always specify which mode