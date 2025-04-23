# FireFly(中文)

FireFly是一个VisionPro项目，在空间中会随机刷新小球，你需要捕获小球。

## 交互性

用右手食指靠近小球，以捕获小球。

## 技术要点

1. 通过`SceneReconstructionProvider`，采集现实环境构造出虚拟环境，让小球的刷新位置不与现实物体冲撞。
2. 通过`WorldTrackingProvider`，在以现实物理位置为中心刷新小球。
3. 通过`RoomTrackingProvider`，保证小球是在当前room刷新。
4. 通过`HandTrackingProvider`，监控当右手食指接触到小球时进行交互。
5. 使用`Component`的特性，达到小球背景、融化和被吸引的动画效果。

# FireFly(EN)

FireFly is a VisionPro project where balls randomly spawn in space, and your task is to capture them.

## Interactivity

Use your right index finger to approach the ball in order to capture it.

## Technical Highlights

1. By using `SceneReconstructionProvider`, the real environment is captured to construct a virtual environment, ensuring that the spawning positions of the balls do not collide with real-world objects.
2. By using `WorldTrackingProvider`, the balls are spawned centered around real-world physical locations.
3. By using `RoomTrackingProvider`, it ensures that the balls are spawned within the current room.
4. By using `HandTrackingProvider`, it monitors interactions when the right index finger touches a ball.
5. Utilizing the features of `Component`, animation effects such as the ball's background, melting, and being attracted are achieved.

https://github.com/mrriddler-feng/FireFly/blob/main/Res/FireFly.MOV
