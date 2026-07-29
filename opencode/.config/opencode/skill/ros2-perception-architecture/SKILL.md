---
name: ros2-perception-architecture
description: Reference for ROS 2 perception pipeline architecture — node composition, lifecycle management, QoS matrix design, and callback group strategy. Use when designing or reviewing perception node structure.
---

# ROS 2 Perception Architecture

## When to Load

- Designing a new perception pipeline (camera → processing → output)
- Reviewing node topology for coupling or QoS issues
- Planning component composition vs separate processes
- Setting up lifecycle managed nodes

## Node Design Principles

1. **Group by fault domain and rate domain.** A 60 Hz camera driver and a 30 Hz detector should be separate nodes or at minimum separate callback groups. A slow inference callback must not backpressure camera acquisition.

2. **Choose communication primitives by semantics:**
   - **Topics**: streaming sensor data, detections, state estimates (`/camera/image_raw`, `/detections`)
   - **Services**: short bounded operations (reload model, set ROI, toggle debug)
   - **Actions**: long-running goal-oriented tasks ("track object X for 30s")

3. **Use lifecycle (managed) nodes** for perception components:
   - Deterministic bring-up: camera driver reaches `active` before inference node subscribes
   - Clean resource release on error recovery
   - State transitions: `unconfigured → inactive → active → inactive → unconfigured → finalized`

## Component Composition

**Compose perception nodes into a single process** for intra-process zero-copy:

```bash
ros2 run rclcpp_components component_container --ros-args \
  -r "my_detection::DetectorNode" \
  -r "my_camera::CameraDriverNode"
```

**When to compose:** Same machine, high-bandwidth inter-node data (image → detection → tracking).

**When NOT to compose:** Different fault domains (detector crash shouldn't kill camera), different update cadences, cross-machine deployment.

**Impact:** Eliminates 2-3 full image copies per hop, 30-50% CPU savings at 1080p/30Hz with 3-node pipelines.

## QoS Matrix for Vision Topics

| Topic Type | Reliability | Durability | History | Rationale |
|-----------|-------------|------------|---------|-----------|
| Camera images | BEST_EFFORT | VOLATILE | KEEP_LAST(5) | Dropped frames OK, latency matters |
| Detection results | RELIABLE | VOLATILE | KEEP_LAST(10) | Downstream depends on completeness |
| Real-time control input | BEST_EFFORT | VOLATILE | KEEP_LAST(1) | Always process newest, never queue stale |
| Point clouds | BEST_EFFORT | VOLATILE | KEEP_LAST(5) | Large data, stale drops fine |
| Model config | RELIABLE | TRANSIENT_LOCAL | KEEP_LAST(1) | Late subscribers need latest config |

**Critical rules:**
- Never use `TRANSIENT_LOCAL` for high-rate image topics (DDS buffers and replays)
- Match publisher/subscriber QoS or connection won't establish
- `SensorDataQoS()` = `KEEP_LAST(5) + BEST_EFFORT + VOLATILE` — good default for sensors

## Lifecycle Dependency Graph

```
camera_driver [active] → detector [active] → tracker [active]
         ↘ [unconfigured] if camera fails
```

Each downstream node should only transition to `active` when its upstream dependencies are active.

## Five-Layer Architecture Model

1. **Device/Driver layer**: cameras, LiDARs, IMUs
2. **State estimation/World model layer**: localization, perception outputs, maps
3. **Behavior/Planning layer**: navigation, task sequencing
4. **Interaction/Mission layer**: teleop, operator UI, fleet APIs
5. **Operations layer**: launch, lifecycle, diagnostics, logging, bagging

Keep perception in layers 1-2. Don't mix planning logic into perception nodes.