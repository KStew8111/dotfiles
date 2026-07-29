---
name: ros2-executor-tuning
description: Reference for ROS 2 executor configuration, callback group design, and latency/jitter debugging in vision pipelines. Use when diagnosing performance issues, blocking callbacks, or scheduling latency.
---

# ROS 2 Executor Tuning for Vision

## When to Load

- Debugging latency spikes or jitter in perception nodes
- Configuring MultiThreadedExecutor vs SingleThreadedExecutor
- Designing callback group assignments
- Using ros2_tracing to find executor bottlenecks

## The Core Problem

**Default `SingleThreadedExecutor` is a trap for composed perception nodes.** If you compose camera driver + image processor + detector into one process with a single-threaded executor, a blocking inference callback will block camera frame acquisition.

All callbacks in a single-threaded executor share **one** thread. If one callback blocks or runs long, **nothing else can run until it finishes**. This includes timer callbacks (control loops) waiting behind subscription callbacks (inference).

## MultiThreadedExecutor Pattern

```cpp
// Production pattern: separate callback groups
auto camera_group = node->create_callback_group(
    rclcpp::CallbackGroupType::MutuallyExclusive);
auto inference_group = node->create_callback_group(
    rclcpp::CallbackGroupType::Reentrant);

// Attach subscribers to appropriate groups
rclcpp::SubscriptionOptions sub_opts;
sub_opts.callback_group = inference_group;
auto sub = node->create_subscription<sensor_msgs::msg::Image>(
    "/camera/image_raw", rclcpp::SensorDataQoS(),
    std::bind(&MyNode::imageCallback, this, _1), sub_opts);

// Multi-threaded executor
rclcpp::executors::MultiThreadedExecutor executor(rclcpp::ExecutorOptions(), 2);
executor.add_node(node);
executor.spin();
```

## Callback Group Types

| Type | Behavior | Use When |
|------|----------|----------|
| `MutuallyExclusive` (default) | Only one callback from this group runs at a time | Callbacks share state — prevents races |
| `Reentrant` | Multiple callbacks from this group can run in parallel | Callbacks are independent, need max parallelism |

**ROS 2 safety guarantee:** Each node only runs one callback at a time by default, even with MultiThreadedExecutor. Parallel execution requires explicit `Reentrant` groups.

## Executor Selection Guide

| Scenario | Executor | Callback Groups |
|----------|----------|-----------------|
| Single node, simple callbacks | SingleThreaded | Default (one group) |
| Composed perception nodes | MultiThreaded | Camera: MutuallyExclusive, Inference: Reentrant |
| Mixed control + perception | MultiThreaded | Control: MutuallyExclusive, Perception: Reentrant |
| High-rate sensor + slow processing | MultiThreaded | Sensor: MutuallyExclusive, Processing: separate group |

## spin() vs spin_some() vs spin_once()

- **`spin()`**: Blocks forever processing callbacks. Use with MultiThreadedExecutor.
- **`spin_some()`**: Processes available callbacks then returns. **Can peg CPU at 100%** if a high-rate publisher keeps the queue full — it never gets to stop. Avoid in production.
- **`spin_once()`**: Processes at most one callback. Use only for testing.

**Rule:** Use `spin()` with a properly configured executor. Avoid `spin_some()` in production.

## Deadlock Pattern to Avoid

```cpp
// DEADLOCK: Service client waits for response on same executor thread
void callback(const Msg::SharedPtr msg) {
    auto result = client->call(request);  // BLOCKS executor
    // This callback is running on the executor thread.
    // The response callback also needs the executor thread.
    // Deadlock.
}
```

**Fix:** Use async service calls:
```cpp
void callback(const Msg::SharedPtr msg) {
    auto result_future = client->async_send_request(request);
    // Set up a callback for the response, don't block here
}
```

## ros2_tracing for Latency Debugging

```bash
# Enable tracing
ros2 trace --session-name perception-trace \
    -u rclcpp:_rmw_publish -u rclcpp:_rmw_take \
    -u rclcpp_callbacks -u rclcpp_executors

# Run your perception pipeline, then stop tracing
# Analyze with TraceCompass or babeltrace
babeltrace perception-trace | grep -E "publish|take|callback"
```

**What to look for:**
- Time between `rmw_publish` and `rmw_take` → DDS transport latency
- Time between `callback_start` and `callback_end` → callback execution time
- Time between `executor_ready` and `callback_start` → executor scheduling delay (this is where blocking shows up)

## Diagnostic Commands

```bash
# Check actual publish rate
ros2 topic hz /camera/image_raw

# Check bandwidth
ros2 topic bw /camera/image_raw

# Check QoS compatibility
ros2 topic info /camera/image_raw -v

# List nodes and their subscriptions
ros2 node info /my_perception_node
```