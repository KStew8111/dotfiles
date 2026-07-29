---
name: ros2-core-reference
description: Core ROS 2 development reference — node architecture, QoS tuning, middleware efficiency, and real-time reliability. Use when writing or reviewing any ROS 2 node code, launch files, or middleware configuration.
---

# ROS 2 Core Reference

## When to Load

- Writing any ROS 2 node (C++ or Python)
- Configuring QoS for topics, services, or actions
- Setting up executors and callback groups
- Writing launch files
- Debugging middleware issues (connections not establishing, messages dropping)

## Operating Principles

1. **Non-Blocking Callbacks.** Never block in a callback. All long-running tasks must use timers, action servers, or dedicated executor threads. A callback that blocks starves every other subscriber on that executor.

2. **QoS Precision.** Use the correct QoS profile for every topic based on data importance. Sensor data = Best Effort; config/state = Reliable + Transient Local. Mismatched QoS between publisher and subscriber is a silent failure.

3. **Middleware Efficiency.** Minimize serialization overhead. Prefer specialized message types over generic ones, right-size message frequency to the consumer's actual need, avoid publishing redundant data.

4. **Decoupling by Design.** Nodes communicate through well-defined interfaces, not shared state. If two nodes need shared memory, consider a single composed node.

## Verification Commands

```bash
ros2 node list                    # Map running nodes
ros2 topic list                   # List all topics
ros2 node info /my_node           # See a node's pub/sub
ros2 topic info /topic -v         # Check QoS compatibility
ros2 topic hz /topic              # Measure publish rate
ros2 topic bw /topic              # Measure bandwidth
ros2 bag record -a                # Record all topics
ros2 bag play my_bag/             # Replay
```

## Common Pitfalls

### Never spin inside a callback
```cpp
// DEADLOCK: spin() inside a callback
void callback(const Msg::SharedPtr msg) {
    rclcpp::spin_some(node);  // NEVER DO THIS
}
```
Use `MultiThreadedExecutor` with callback groups, or offload to a separate thread.

### QoS mismatches are silent
- Reliable publisher + Best Effort subscriber → works (subscriber gets messages)
- Best Effort publisher + Reliable subscriber → **silently drops messages**
- Always verify QoS on both ends with `ros2 topic info /topic -v`

### Don't use global variables in nodes
ROS 2 nodes are instantiated, not static. Globals break composability and testing. Pass state through node members.

### Lifecycle transitions are not optional
`on_configure → on_activate → on_deactivate → on_cleanup` — skipping transitions leads to resource leaks and undefined state.

### tf2 buffers need time to populate
```cpp
// WRONG: will throw if transform not yet available
auto tf = buffer.lookupTransform("base_link", "camera", tf2::TimePointZero);

// RIGHT: use canTransform with timeout
if (buffer.canTransform("base_link", "camera", tf2::TimePointZero, 1s)) {
    auto tf = buffer.lookupTransform("base_link", "camera", tf2::TimePointZero);
}
```

### Don't block on service calls in callbacks
```cpp
// WRONG: freezes the executor
auto result = client->call(request);

// RIGHT: async
auto future = client->async_send_request(request, callback);
```

### Parameter callbacks must be thread-safe
`set_parameters_callback` runs on the executor thread while publishers may run on another. Guard shared state.

## Scope

- **In scope:** ROS 2 node architecture, QoS, executors, lifecycle, launch files, composable nodes, message design, tf2, intra-process communication.
- **Defer to ros2-gpu-acceleration:** TensorRT, CUDA kernels, Jetson-specific optimization.
- **Defer to ros2-transport-optimization:** Zero-copy, SHM, image transport plugins.
- **Defer to ros2-executor-tuning:** Latency debugging, tracing, callback group design.