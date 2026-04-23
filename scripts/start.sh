bash scripts/event_camera_intrinsics_calib.sh \
  --input-bag data/calibr.bag \
  --output-dir data/calib_output \
  --event-topic /capture_node/events \
  --target-type apriltag \
  --tag-rows 4 \
  --tag-cols 4 \
  --tag-size-m 0.005 \
  --tag-spacing 0.5
