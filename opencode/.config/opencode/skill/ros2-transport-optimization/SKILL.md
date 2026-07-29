---
name: ros2-transport-optimization
description: Reference for zero-copy transport, shared memory configuration, and image transport plugin selection in ROS 2 vision pipelines. Use when optimizing data paths between perception nodes.
---

# ROS 2 Transport Optimization for Vision

## When to Load

- Reducing copy overhead between perception nodes
- Configuring DDS shared memory transport
- Selecting image transport plugins
- Setting up zero-copy pub/sub

## Zero-Copy: Intra-Process (Same Process)

Use `std::unique_ptr` with `publish(std::move(msg))` — subscriber receives a shared pointer, no copy. Requires nodes to be **composed** into the same process.

```cpp
auto msg = std::make_unique<sensor_msgs::msg::Image>();
// populate msg...
publisher->publish(std::move(msg));  // zero-copy intra-process
```

**This is the single most impactful optimization for composed perception pipelines.**

## Zero-Copy: Inter-Process (Shared Memory)

**Option 1: ros2_shm_msgs** (bounded types with loaned message API)
- Provides bounded `Image1m`, `PointCloud2` types that support zero-copy
- ~80% transport time reduction (1.4ms → 0.3ms for 1MB image on x86)
- Uses `borrow_loaned_message()` API:

```cpp
auto loanedMsg = publisher->borrow_loaned_message();
populateLoanedMessage(loanedMsg);
publisher->publish(std::move(loanedMsg));  // zero-copy publish
```

**Option 2: DDS SHM transport** (FastDDS / CycloneDDS)
- Configure shared memory transport in DDS XML profile
- Works with standard message types but still serializes
- Less efficient than loaned message API but no code changes needed

**Caveat:** Standard `sensor_msgs/Image` is unbounded — doesn't support zero-copy in default DDS. Use `ros2_shm_msgs` types or type adaptation (Humble+).

## Image Transport Plugin Selection

| Plugin | Use Case | Notes |
|--------|----------|-------|
| `raw` | Intra-process, short hops | No overhead, max fidelity |
| `compressed` (JPEG/PNG) | Network transport, recording | ~10x bandwidth reduction, lossy |
| `ffmpeg_image_transport` (H.264/H.265) | High-latency links, remote viewing | HW-accelerated on Jetson |
| `theora` | Legacy, avoid | Slow, poor quality |

**Production recommendations:**
- Raw transport for intra-process perception pipelines (no compression overhead)
- Compressed/H.264 only for cross-network transport (teleop, remote monitoring)
- Publish both `/camera/image_raw` and `/camera/image_compressed` — let consumers choose
- For 120+ FPS cameras, publish compressed directly from driver to avoid raw bandwidth saturation

## Bandwidth Math

- 1080p BGR8 @ 30 Hz = 1920×1080×3×30 = ~187 MB/s
- Each copy (serialize, transport, deserialize) eats CPU and adds latency
- 3-node pipeline without zero-copy = 6+ copies = ~1.1 GB/s memory bandwidth wasted

## DDS Vendor Configuration

**FastDDS SHM transport:**
```xml
<transport_descriptors>
  <shared_mem_transport>
    <segment_size>1048576</segment_size>  <!-- 1MB segments -->
    <port_queue_capacity>1024</port_queue_capacity>
  </shared_mem_transport>
</transport_descriptors>
```

**CycloneDDS SHM:**
```xml
<CycloneDDS>
  <Domain>
    <SharedMemory>
      <Enable>true</Enable>
      <LogLevel>info</LogLevel>
    </SharedMemory>
  </Domain>
</CycloneDDS>
```