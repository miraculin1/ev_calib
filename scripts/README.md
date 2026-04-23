# Event Camera Intrinsics Calibration

仓库总览、workspace 编译流程和最小运行路径见根 README：

- [README.md](/workspace/calib_nail/README.md)

这个目录提供了一组围绕事件相机内参标定的辅助脚本。当前完整流程是：

1. 录制包含事件话题的 ROS1 bag
2. 用 `simple_image_recon` 将事件流重建成图像 bag
3. 用 Kalibr 对重建图像话题做内参标定

当前主标定入口是 `scripts/event_camera_intrinsics_calib.sh`，默认面向单个事件相机话题，输入事件消息类型为 `dv_ros_msgs/EventArray`。

## Files

- `scripts/README.md`: 本文档
- `scripts/record.sh`: 录制 ROS1 bag 的辅助脚本
- `scripts/event_camera_intrinsics_calib.sh`: 主标定脚本
- `scripts/start.sh`: 仓库内示例启动命令
- `scripts/gen_target.sh`: 调用 `kalibr_create_target_pdf` 生成 AprilTag 标定板 PDF 的辅助命令
- `scripts/target.pdf`: 当前目录下的示例标定板 PDF

## Run from Repo Root

下面的示例命令默认都需要在项目根目录执行：

```bash
cd /workspace/calib_nail
```

原因是这些脚本示例里使用了相对路径，例如：

- `scripts/...`
- `data/calibr.bag`
- `data/calib_output`

如果你不在项目根目录执行，录制和标定相关路径可能会落到错误位置。

## Prerequisites

使用前需要满足：

- 已先按根 README 完成 ROS1 catkin workspace 编译。
- `devel/setup.bash` 存在。
- `rosrun simple_image_recon bag_to_frames` 可以被找到。
- `rosrun kalibr kalibr_calibrate_cameras` 可以被找到。
- 事件相机驱动已经启动，并且 `/capture_node/events` 正在发布。

如果你还没有完成构建，先看根文档中的编译说明：

- [README.md](/workspace/calib_nail/README.md)

默认标定脚本会 source：

```bash
/workspace/calib_nail/devel/setup.bash
```

如果你的 workspace 不在这个路径，使用 `--workspace-dir` 或 `--setup-bash` 覆盖即可。

## Record Data

录制脚本当前内容是：

```bash
rosbag record /capture_node/events -O data/calibr
```

在项目根目录执行：

```bash
cd /workspace/calib_nail
bash scripts/record.sh
```

录制成功后，输出文件会是：

```bash
data/calibr.bag
```

停止录制时，在运行中的终端里按 `Ctrl+C` 即可。

## Quick Start

### 1. Run the Main Calibration Script

在项目根目录执行：

```bash
cd /workspace/calib_nail

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

### 2. AprilTag Grid Example

在项目根目录执行：

```bash
cd /workspace/calib_nail

bash scripts/event_camera_intrinsics_calib.sh \
  --input-bag data/calibr.bag \
  --output-dir data/calib_output \
  --event-topic /capture_node/events \
  --target-type apriltag \
  --tag-rows 6 \
  --tag-cols 6 \
  --tag-size-m 0.005 \
  --tag-spacing 0.3
```

### 3. Use Existing Target YAML

在项目根目录执行：

```bash
cd /workspace/calib_nail

bash scripts/event_camera_intrinsics_calib.sh \
  --input-bag data/calibr.bag \
  --output-dir data/calib_output \
  --event-topic /capture_node/events \
  --target-yaml /path/to/target.yaml
```

### 4. Use the Included Start Script

如果你只是想快速复用仓库里的默认示例，也可以在项目根目录执行：

```bash
cd /workspace/calib_nail
bash scripts/start.sh
```

`start.sh` 本质上只是对主脚本的一组示例参数封装，不是独立接口。

## Parameters

### Required Parameters

- `--input-bag PATH`
  输入 ROS1 bag 文件路径。

- `--output-dir PATH`
  输出目录。脚本会在这里创建：
  - `reconstructed/`: 事件重建后的 bag
  - `kalibr/`: Kalibr 结果文件副本
  - `logs/`: 运行日志
  - `tmp/`: 自动生成 target YAML 时使用的临时目录

- `--event-topic TOPIC`
  输入 bag 中的事件话题，例如 `/capture_node/events`。

### Target Configuration Parameters

二选一：

- `--target-yaml PATH`
  直接使用已有的 Kalibr target YAML。传这个参数时，脚本不会生成 target YAML。

- `--target-type checkerboard|apriltag`
  让脚本按传入几何参数自动生成 target YAML。

#### Checkerboard Parameters

当 `--target-type checkerboard` 时，必须提供：

- `--target-rows N`
  棋盘格行方向的内角点数量。

- `--target-cols N`
  棋盘格列方向的内角点数量。

- `--row-spacing-m VALUE`
  行方向相邻角点间距，单位米。

- `--col-spacing-m VALUE`
  列方向相邻角点间距，单位米。

自动生成的 YAML 格式等价于：

```yaml
target_type: 'checkerboard'
targetRows: 6
targetCols: 8
rowSpacingMeters: 0.03
colSpacingMeters: 0.03
```

#### AprilTag Parameters

当 `--target-type apriltag` 时，必须提供：

- `--tag-rows N`
  AprilTag 网格行数。

- `--tag-cols N`
  AprilTag 网格列数。

- `--tag-size-m VALUE`
  单个 tag 边长，单位米。

- `--tag-spacing VALUE`
  tag 间距与 tag 边长的比值。
  例如 tag 边长 0.1 m，间隙 0.03 m，则这里应传 `0.3`。

自动生成的 YAML 格式等价于：

```yaml
target_type: 'aprilgrid'
tagRows: 6
tagCols: 6
tagSize: 0.005
tagSpacing: 0.3
```

## Optional Parameters

### Workspace and Environment

- `--workspace-dir PATH`
  catkin workspace 根目录。默认是当前仓库根目录。

- `--setup-bash PATH`
  需要 source 的 setup 脚本。默认是 `${workspace-dir}/devel/setup.bash`。

### Event Reconstruction Parameters

- `--recon-bag PATH`
  指定重建后的输出 bag 路径。
  默认输出到：

```bash
${output-dir}/reconstructed/<input_bag_name>_reconstructed.bag
```

- `--image-topic TOPIC`
  指定重建后写入 bag 的图像话题。
  默认值是：

```bash
<event-topic>/image_raw
```

例如事件话题是 `/capture_node/events`，默认图像话题就是 `/capture_node/events/image_raw`。

- `--fps VALUE`
  `bag_to_frames` 的重建帧率，默认 `30`，必须为正数。

- `--cutoff-period N`
  `bag_to_frames` 的 cutoff period，默认 `30`，必须为正整数。

- `--time-offset SEC`
  传给 `bag_to_frames -O` 的时间偏移，单位秒，必须非负。
  默认 `0`。

### Kalibr Parameters

- `--camera-model MODEL`
  Kalibr 相机模型。默认 `pinhole-radtan`。

常见可选值取决于 Kalibr 支持的模型，例如：

- `pinhole-radtan`
- `pinhole-equi`
- `pinhole-fov`
- `omni-radtan`
- `omni-none`
- `eucm-none`
- `ds-none`

- `--bag-freq VALUE`
  Kalibr 的 `--bag-freq`，默认 `5`，必须为正数。

- `--approx-sync SEC`
  Kalibr 的 `--approx-sync`，只在需要时传入，必须为正数。

- `--show-extraction`
  把 `--show-extraction` 透传给 Kalibr，用于查看角点或 tag 提取过程。

- `--kalibr-verbose`
  把 `--verbose` 透传给 Kalibr，输出更详细的调试信息。

- `--export-poses`
  把 `--export-poses` 透传给 Kalibr，导出优化后的位姿文件。

### Temporary Files

- `--keep-temp`
  默认脚本会在结束时删除自动生成的 target YAML。
  加上这个参数后，会保留 `output-dir/tmp/` 中自动生成的 YAML 文件。

## Output Files

假设输入 bag 为：

```bash
data/calibr.bag
```

输出目录为：

```bash
data/calib_output
```

则脚本会创建：

- `data/calib_output/reconstructed/`
- `data/calib_output/kalibr/`
- `data/calib_output/logs/`
- `data/calib_output/tmp/`

其中常见输出包括：

- `data/calib_output/reconstructed/calibr_reconstructed.bag`
  重建后的图像 bag。

- `data/calib_output/logs/bag_to_frames.log`
  事件重建日志。

- `data/calib_output/logs/kalibr_calibrate_cameras.log`
  Kalibr 日志。

- `data/calib_output/kalibr/calibr_reconstructed-camchain.yaml`
  Kalibr 输出的相机链 YAML。

- `data/calib_output/kalibr/calibr_reconstructed-results-cam.txt`
  详细标定结果。

- `data/calib_output/kalibr/calibr_reconstructed-report-cam.pdf`
  Kalibr 生成的 PDF 报告。

- `data/calib_output/kalibr/calibr_reconstructed-poses-cam0.csv`
  如果使用了 `--export-poses`，还会有这个文件。

注意：

- Kalibr 原始输出文件会先生成在重建 bag 同目录下，脚本随后会复制一份到 `output-dir/kalibr/` 便于集中查看。
- 自动生成的 target YAML 默认会在脚本退出时删除；只有加了 `--keep-temp` 才会保留在 `output-dir/tmp/`。

## How the Script Maps to the Underlying Tools

脚本内部大致等价于下面两条命令。

### Step 1: Reconstruct Frames

```bash
rosrun simple_image_recon bag_to_frames \
  -i <input_bag> \
  -o <recon_bag> \
  -t <event_topic> \
  -T <image_topic> \
  -f <fps> \
  -c <cutoff_period> \
  -O <time_offset>
```

### Step 2: Run Kalibr

```bash
rosrun kalibr kalibr_calibrate_cameras \
  --target <target_yaml> \
  --models <camera_model> \
  --topics <image_topic> \
  --bag <recon_bag> \
  --bag-freq <bag_freq> \
  --dont-show-report
```

如果你额外传了 `--approx-sync`、`--show-extraction`、`--kalibr-verbose`、`--export-poses`，脚本会把它们继续透传给 Kalibr。

## Target Board

当前目录还提供了一个辅助生成脚本。在项目根目录执行：

```bash
cd /workspace/calib_nail
bash scripts/gen_target.sh
```

它当前实际执行的是：

```bash
rosrun kalibr kalibr_create_target_pdf --type apriltag --nx 4 --ny 4 --tsize 0.05 --tspace 0.5
```

这会生成一个 4x4 的 AprilTag 标定板 PDF。`scripts/target.pdf` 是当前目录下保存的示例板文件。

注意：这份 4x4 标定板和上面主脚本示例里使用的 6x6 AprilTag 参数不是同一个板。实际标定时，必须确保以下三者一致：

- 你实际打印或使用的标定板
- 传给主脚本的 target 参数或 `--target-yaml`
- Kalibr 最终读取到的 target YAML

## Troubleshooting

- 报错 `setup.bash` 不存在：
  检查 workspace 是否已编译，或者显式传 `--setup-bash`。

- 报错 `rosrun simple_image_recon bag_to_frames` 不可用：
  检查 `simple_image_recon` 是否已正确编译并包含在当前 workspace 环境中。

- 报错 `rosrun kalibr kalibr_calibrate_cameras` 不可用：
  检查 `kalibr` 是否已正确编译并包含在当前 workspace 环境中。

- Kalibr 提示无法初始化内参：
  通常意味着标定板提取失败、事件重建效果不足，或者 target 几何参数与实际板子不一致。

- `checkerboard` / `apriltag` 提取效果差：
  优先检查：
  - 标定板实际尺寸是否与参数一致
  - `fps` 是否过低或过高
  - 事件图像是否足够清晰
  - bag 中目标是否覆盖了足够多的视角和位置

## Help

查看脚本帮助：

```bash
cd /workspace/calib_nail
bash scripts/event_camera_intrinsics_calib.sh --help
```
