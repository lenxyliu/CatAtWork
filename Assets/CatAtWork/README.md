# 猫上班了素材生产

`identity/canonical-turnaround.png` 是所有动作生成的唯一身份基准。动作帧必须使用它作为图像参考，保持相同头宽、躯干长度、眼距、腿粗和尾巴体积。

每个正式动作由三个连续的 8 帧组组成：`phase-a`、`phase-b`、`phase-c`。组之间共享边界姿势证据；循环动作还必须验证 `023 -> 000`。

最终帧保存到：

```text
frames/<animation>/000.png ... 023.png
```

禁止按单帧边界框重新缩放。所有帧使用同一 `pixelsPerBodyUnit`，只记录透明裁切矩形和脚底锚点。
