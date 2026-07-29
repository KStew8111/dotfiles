---
name: ros2-perception-hardening
description: Reference for production hardening of ROS 2 perception nodes — lifecycle conversion, diagnostics, rosbag recording, parameter validation, and observability. Use when preparing perception nodes for deployment.
---

# ROS 2 Perception Hardening

## When to Load

- Converting standard nodes to lifecycle nodes
- Adding diagnostics to perception nodes
- Setting up rosbag recording in launch files
- Adding parameter validation
- Implementing graceful shutdown / error recovery
- Designing observability for production deployment

## Lifecycle Node Conversion

Convert `rclcpp::Node` to `rclcpp_lifecycle::LifecycleNode`:

```cpp
class PerceptionNode : public rclcpp_lifecycle::LifecycleNode {
public:
  PerceptionNode() : LifecycleNode("perception_node") {}

  // unconfigured -> inactive
  rclcpp_lifecycle::node_interfaces::LifecycleNodeInterface::CallbackReturn
  on_configure(const rclcpp_lifecycle::State&) {
    // Initialize publishers, subscribers, parameters
    // Do NOT start processing yet
    return SUCCESS;
  }

  // inactive -> active
  rclcpp_lifecycle::node_interfaces::LifecycleNodeInterface::CallbackReturn
  on_activate(const rclcpp_lifecycle::State&) {
    // Start processing, activate publishers
    return SUCCESS;
  }

  // active -> inactive
  rclcpp_lifecycle::node_interfaces::LifecycleNodeInterface::CallbackReturn
  on_deactivate(const rclcpp_lifecycle::State&) {
    // Pause processing, deactivate publishers
    return SUCCESS;
  }

  // inactive -> unconfigured
  rclcpp_lifecycle::node_interfaces::LifecycleNodeInterface::CallbackReturn
  on_cleanup(const rclcpp_lifecycle::State&) {
    // Release resources, delete publishers/subscribers
    return SUCCESS;
  }

  // unconfigured -> finalized
  rclcpp_lifecycle::node_interfaces::LifecycleNodeInterface::CallbackReturn
  on_shutdown(const rclcpp_lifecycle::State&) {
    return SUCCESS;
  }
};
```

## Diagnostics

Publish `diagnostic_msgs/DiagnosticArray` for perception health:

```cpp
#include <diagnostic_updater/diagnostic_updater.hpp>

diagnostic_updater::Updater diag_updater_(this);
diag_updater_.setHardwareID("camera_0");

// FPS diagnostic
auto fps_diag = [](diagnostic_updater::DiagnosticStatusWrapper &stat) {
    stat.summary(diagnostic_msgs::msg::DiagnosticStatus::OK, "Camera OK");
    stat.add("FPS", current_fps_);
    stat.add("Dropped Frames", dropped_frames_);
    stat.add("Temperature", camera_temp_);
};
diag_updater_.add("Camera Health", fps_diag);

// Inference latency diagnostic
auto inference_diag = [](diagnostic_updater::DiagnosticStatusWrapper &stat) {
    if (inference_latency_ms_ > 50.0) {
        stat.summary(diagnostic_msgs::msg::DiagnosticStatus::WARN, "High inference latency");
    } else {
        stat.summary(diagnostic_msgs::msg::DiagnosticStatus::OK, "Inference OK");
    }
    stat.add("Latency (ms)", inference_latency_ms_);
    stat.add("Model Confidence", avg_confidence_);
};
diag_updater_.add("Inference Health", inference_diag);
```

## rosbag2 Recording in Launch

```python
import launch
import launch_ros.actions

def generate_launch_description():
    return launch.LaunchDescription([
        # Your perception nodes...
        launch_ros.actions.Node(
            package='rosbag2_recorder',
            executable='recorder',
            name='rosbag2_recorder',
            parameters=[{
                'all': True,
                'max_bag_size': 5000000000,  # 5GB split
                'max_bag_duration': 300,     # 5 min split
                'max_cache': 100000000,     # 100MB cache
            }],
            output='screen',
        ),
    ])
```

## Parameter Validation

```cpp
// Declare parameters with validation constraints
this->declare_parameter("image_topic", "/camera/image_raw");
this->declare_parameter("inference_fps", 30.0,
    rcl_interfaces::msg::ParameterDescriptor()
        .set__floating_point_range({0.1, 120.0})
        .set__description("Target inference rate in Hz (0.1-120)"));

this->declare_parameter("model_path", "",
    rcl_interfaces::msg::ParameterDescriptor()
        .set__read_only(true)
        .set__description("Path to TensorRT engine file (required)"));

// Validate at configure time
auto model_path = this->get_parameter("model_path").as_string();
if (model_path.empty()) {
    RCLCPP_ERROR(this->get_logger(), "model_path is required");
    return FAILURE;  // Block lifecycle transition
}
```

## Observability Stack

| Tool | What It Catches | When to Use |
|------|----------------|-------------|
| `ros2_tracing` (LTTng) | Callback timing, executor scheduling, DDS latency | Debugging "random" latency spikes |
| `ros2 bag` | Full message replay | Post-incident analysis, regression testing |
| `diagnostic_updater` | Runtime health (FPS, temp, latency) | Continuous monitoring, fleet ops |
| `ros2 topic hz/bw` | Rate and bandwidth verification | Quick sanity checks |
| `rqt_graph` | Node/topic topology visualization | Architecture review |
| Structured logging (rcutils) | Severity-filtered log analysis | Debug, error tracking |

## Graceful Shutdown Checklist

- [ ] All nodes implement `on_deactivate` and `on_cleanup`
- [ ] Inference nodes cancel pending GPU work before cleanup
- [ ] Camera drivers stop acquisition before releasing hardware
- [ ] rosbag2 flushes and closes cleanly
- [ ] No `SIGKILL` required for clean shutdown — `SIGINT` should suffice
- [ ] Parameters reloaded on restart (not cached in globals)