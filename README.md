<p align="center">
  <img src="Assets/AppIcon.png" width="96" alt="Physics Diagram Studio">
</p>

<h1 align="center">Physics Diagram Studio</h1>

<p align="center">
  把物理题，变成清晰、可编辑、可导出的教学图示。
</p>

<p align="center">
  原生 macOS 应用 · OpenAI-compatible 接口 · 支持文字与图片输入
</p>

---

## 它适合什么

Physics Diagram Studio 面向老师、学生、内容创作者和理科笔记用户。你可以输入一道物理题，也可以拖入题目截图，让具备多模态能力的模型识别题意，并生成结构清晰的 SVG 图示。

它不是一个复杂的绘图软件，而是一个更轻的图示生成工作台：输入题目，检查结果，保存或导出。

## 主要功能

- 文字题目生成物理图示
- 图片拖入题目输入框，自动附加给模型识别
- `Control + P` 打开截图，框选题目区域后直接发送给模型
- 支持 OpenAI-compatible API，可配置 Base URL、API Key、模型和温度
- 生成结果自动保存为 SVG、PNG 和 HTML
- 历史图示本地保存，可随时预览和导出

## 快速开始

从源码运行：

```bash
./script/build_and_run.sh
```

首次打开后，进入右上角“设置”，填写：

- `Base URL`
- `API Key`
- `Model`
- `Temperature`

推荐使用 GPT-5.5 或其他具备多模态能力的模型。若要处理截图或拖入图片，模型必须支持图片输入。

## 使用方式

1. 在“题目输入”中输入物理题，或拖入题目图片。
2. 如需截图，按 `Control + P` 后框选题目区域。
3. 点击“生成图示”。
4. 在“图示”区域预览生成结果。
5. 使用“导出”保存 SVG、PNG 和 HTML 文件。

## 数据与隐私

生成记录保存在本机：

```text
~/Library/Application Support/PhysicsDiagramStudio/Diagrams
```

请求会直接发送到你在设置中配置的 API 服务商。题目文字和附加图片会作为模型输入发送，请避免提交不希望第三方服务商处理的敏感内容。

API Key 保存在本机应用偏好设置中。当前版本不会使用 macOS 钥匙串，以避免开发版应用反复触发钥匙串授权弹窗。

## 系统要求

- macOS 14 或更高版本
- 可用的 OpenAI-compatible API 服务
- 推荐使用具备多模态能力的模型

## 许可证

本项目基于 Apache License 2.0 开源。

详见 [LICENSE](LICENSE)。
