# calib_nail

`calib_nail` 是一个 ROS1 catkin workspace，当前主目标是跑通单事件相机内参标定链路：

1. 录制事件相机 ROS bag
2. 用 `simple_image_recon` 将 `dv_ros_msgs/EventArray` 重建为图像
3. 用 Kalibr 对重建图像做相机内参标定

当前主入口已经整理到 `scripts/`。根 README 负责项目概览、编译流程和最小使用路径；参数细节、输出说明和脚本级排障见脚本文档。

## Main Workflow

当前推荐流程：

1. 在 ROS Noetic 环境下构建整个 workspace
2. 录制包含事件话题的 ROS1 bag
3. 运行 `scripts/event_camera_intrinsics_calib.sh`
4. 查看重建结果和 Kalibr 输出

当前主链路输入的事件消息类型是：

```text
dv_ros_msgs/EventArray
```

## Repository Layout

主链路相关目录：

- `src/dv-ros`
  `dv_ros_msgs/EventArray` 等消息定义和相关 ROS 包
- `src/simple_image_recon`
  事件流到图像的 ROS 重建入口
- `src/simple_image_recon_lib`
  重建核心库
- `src/kalibr`
  相机标定工具
- `scripts/`
  当前推荐使用的脚本入口和文档

工作区构建产物：

- `build/`
- `devel/`
- `logs/`
- `data/`

## Build

建议环境：Ubuntu 20.04 + ROS Noetic。

### Prerequisites

开始前需要具备：

- ROS Noetic
- `catkin_tools`
- `dv-ros` 和 Kalibr 所需的系统依赖

其中 `dv-ros` 在当前仓库中的建议编译器配置是 `gcc-13` / `g++-13`。如果系统依赖未准备完整，优先参考：

- [src/dv-ros/README.md](/workspace/calib_nail/src/dv-ros/README.md)
- [src/kalibr/README.md](/workspace/calib_nail/src/kalibr/README.md)

### Configure and Build

在 workspace 根目录执行：

```bash
source /opt/ros/noetic/setup.bash
cd /workspace/calib_nail

catkin init
catkin config --extend /opt/ros/noetic
catkin config --merge-devel
catkin config --cmake-args \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_COMPILER=/usr/bin/gcc-13 \
  -DCMAKE_CXX_COMPILER=/usr/bin/g++-13

CC=/usr/bin/gcc-13 CXX=/usr/bin/g++-13 catkin build
source devel/setup.bash
```

编译完成后，`devel/setup.bash` 应存在，且 `rosrun simple_image_recon bag_to_frames` 可以被找到。

## Quick Start

完成上面的编译后，执行单脚本标定入口。下面是一个 checkerboard 示例：

```bash
bash scripts/event_camera_intrinsics_calib.sh \
  --input-bag data/calibr.bag \
  --output-dir data/calib_output \
  --event-topic /capture_node/events \
  --target-type checkerboard \
  --target-rows 6 \
  --target-cols 8 \
  --row-spacing-m 0.03 \
  --col-spacing-m 0.03
```

脚本会依次执行两步：

1. `rosrun simple_image_recon bag_to_frames`
2. Kalibr `kalibr_calibrate_cameras`

常见输出位于：

- `data/calib_output/reconstructed/`
- `data/calib_output/logs/`
- `data/calib_output/kalibr/`

## Input and Output

最小输入要求：

- 一个 ROS1 `.bag` 文件
- bag 中包含事件话题，例如 `/capture_node/events`

最小输出结果：

- 重建后的图像 bag
- 重建日志和 Kalibr 日志
- Kalibr 导出的标定结果文件

## Related Docs

- 脚本入口：[scripts/event_camera_intrinsics_calib.sh](/workspace/calib_nail/scripts/event_camera_intrinsics_calib.sh)
- 详细使用说明：[scripts/README.md](/workspace/calib_nail/scripts/README.md)
- 事件重建说明：[src/simple_image_recon/README.md](/workspace/calib_nail/src/simple_image_recon/README.md)
- Kalibr 上游说明：[src/kalibr/README.md](/workspace/calib_nail/src/kalibr/README.md)
