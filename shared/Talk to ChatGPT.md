Talk to ChatGPT

好了之前的agent删除干净了，现在我要重新生成4个agents：architect, builder, ml_vision, debug_test.他们的markdown文件存放在/Users/jiansun/.openclaw/agents下。

请记得生成对应的workspace。

同时我想告诉它们用于开发real time video segmentation ios app的yolo-v9和Mobile Segment Anything (MobileSAM)的的权重文件放在/Users/jiansun/Documents/PostDoc/CODE-SHOW/APP/JudgeE2/models下,分别是yolov9-c.pt和mobile_sam.pt。

每日的工作任务在/Users/jiansun/Documents/PostDoc/CODE-SHOW/APP/JudgeE2/shared/task.md

请根据上面描述生成供openclaw执行命令的markdown code,要可复制的。

-------
旋转后的屏幕截图在/Users/jiansun/Documents/PostDoc/CODE-SHOW/APP/JudgeE2/shared
下面是结果描述。
rotate_270.PNG：Landscape Left，no bbox show up.

rotate_90.PNG:Landscape Right，no bbox show up.

rotate_180.PNG:Portrait Upside Down，no bbox show up.

-------
旋转后的屏幕截图在/Users/jiansun/Documents/PostDoc/CODE-SHOW/APP/JudgeE2/shared
下面是结果描述，请浏览每一张图片。
rotate_180.PNG:Portrait Upside Down，现在正常了，能看到框了。

rotate_270.PNG：Landscape Left，no bbox show up.镜头画面被旋转了90度，实际上镜头里的画面不应该被旋转。

rotate_90.PNG：Landscape Right，no bbox show up.镜头画面被旋转了270度，实际上镜头里的画面不应该被旋转。

同时，没有看到开启前置摄像头的切换按钮。

-------
旋转后的屏幕截图在/Users/jiansun/Documents/PostDoc/CODE-SHOW/APP/JudgeE2/shared
下面是结果描述，请浏览每一张图片。
rotate_270.PNG：Landscape Left，能看到bbox框了.但是你可以看到镜头画面被顺时针旋转了90度，但是实际上镜头里的画面不应该有任何转动。镜头不能因为自己选转就把画面也旋转，而且还转错了。

rotate_90.PNG：Landscape Right，能看到bbox框了.但是你可以看到镜头画面被逆时针旋转了90度，但是实际上镜头里的画面不应该有任何转动。镜头不能因为自己选转就把画面也旋转，而且还转错了。

front_camera.PNG：Flap to front camera, no bbox show up.

-------
感谢@Architect，@Builder，@ML_Vision，@Debugger的辛勤工作，Phase 1及时完成了。
在开始Phase 2 之前，我想明确整个项目剩下的主干任务。

## 需要JudgeE2实现的更多功能
1. 在Yolo-v9基础上，用MobileSAM实现real time instance segmentation，并highlight segmented区域.
2. 基于无目标segmentation，对于用户点击或选定的区域或object进行实例分割。
3. 对于分割的区域添加pin，当点击pin的时候，允许用户添加tag和写注释，并且记住这个pin，用户可以反复查看。
4. 给App做UI设计，让它更像app

## tasks
1. 基于前面上传的已完成的Phase 1 tasks，计划的Phase 2 任务，和上述的功能，分成几个7 day phase来实现。
2. 详细给出Phase 2的计划，每天只给必要的agent布置任务，并按照agents的调度顺序来列出任务。
3. 要求Phase 2要和Phase 1丝滑衔接和过度，这样可以降低我的工作难度。
3. 对于其余Phases给出大致计划。

## big picture
1. 先实现上面的functions，让整个项目由一个初步产出
2. 后面我们会优化整个app，做得更好

## output
1. 结果以markdown code的形式输出




