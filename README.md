# VOFA+ 自定义协议工具箱

给 [VOFA+](https://www.vofa.plus/)（固特加上位机）用的一套小工具，围绕**自定义二进制协议**的配置与查看：

1. **config-tool —— 自定义协议配置工具**（C# WinForms，单文件 exe，无第三方依赖）
   图形化编辑协议引擎的配置文件 `configurable_engine.json`：帧头 / 帧序号 / 帧ID / 帧长度 / 1~8Byte 字段 / 定长数组 / 变长数组 / 校验 / 帧尾。
   字段可设类型（整数/浮点）、偏移、字节序、倍率、偏置；保存后 **VOFA+ 约 1 秒内热重载，不用重启**。
2. **qml-widget —— 只读协议状态控件**
   放进 `plugins/widgets/` 后，在 VOFA+ 画布上以**表格形式**显示当前协议（帧头 / 帧尾 / 定长 / 通道数 / 字段列表 / 校验），每秒自动刷新。

> 本项目是社区实现，与 VOFA+ 官方**无隶属关系**。

---

## ⚠️ 协议解析插件来源（务必保留此声明）

本工具箱**不包含协议解析引擎本身** —— 它编辑和展示的，是下面这个开源项目的配置文件：

| 组件 | 来源 | 许可 |
|---|---|---|
| **协议引擎 `ConfigurableEngine.dll`，以及 `configurable_engine.json` 的格式定义** | [saltfishfly/vofa-configurable-engine](https://github.com/saltfishfly/vofa-configurable-engine) | MIT |
| **协议引擎接口 ABI**（`DataEngineInterface` / `Frame` / `RawImage`） | [je00/Vodka](https://github.com/je00/Vodka) → `dataengines/shared` | MIT |
| **自定义控件的 QML 结构与 API**（`ResizableRectangle` / `MyMenu` / `ChMenu` 等 `MyModules`） | VOFA+ 官方《自定义控件开发》文档 + `Vodka/widgets/example` | MIT |

安装协议引擎：把上游仓库的 `dist/ConfigurableEngine.dll`、`configurable_engine.json`、`ConfigurableEngine.json`
复制到 `<VOFA+ 安装目录>\plugins\dataengines\`，重启 VOFA+ 后在“数据格式”里选择 `ConfigurableEngine`。

配置文件的字段语义、定帧规则（定长 / 长度字段 / 帧尾）、校验算法（SUM8 / XOR8 / CRC16-MODBUS）
全部由上述协议引擎定义，**本工具只负责生成和展示这个 JSON**。

---

## 目录结构

```
vofa-protocol-toolkit/
├── config-tool/                      配置工具（可直接使用）
│   ├── VofaProtocolTool.exe          工具本体（直接双击运行）
│   ├── VofaProtocolTool.exe.config   WinForms PerMonitorV2 高 DPI 配置（必须与 exe 同名）
│   ├── tool.ico                      图标（基于 VOFA+ 图标加角标，见文末声明）
│   ├── preview256.png / preview48.png / preview64.png
│   └── src/
│       ├── ProtocolTool.src.txt      C# 源码（单文件，约 2000 行）
│       └── app.manifest              高 DPI 清单（编译时 /win32manifest 用）
└── qml-widget/
    └── VofaProtoView/
        └── VofaProtoView.qml         VOFA+ 只读协议控件
```

---

## 快速使用

### 1. 配置工具

1. 把 `config-tool/` 拷到任意位置（例：`D:\tools\vofa-protocol-tool\`）；
2. 双击 `VofaProtocolTool.exe`；建议建个桌面快捷方式（图标选 `VofaProtocolTool.exe,0`）；
3. 用顶部按钮加字段：`帧头 / 帧序号 / 帧ID / 帧长度 / 1~8Byte / 定长数组 / 变长数组 / 校验 / 帧尾`
   - 表格里**灰色数字 = 只读**（长度由类型决定），**黑色 = 可输入**（按 HEX 自动分段，提交时高位补 0）；
   - `#` 列**长按 100ms 可上下拖动排序**；表格上方有 `保存 / 上移 / 下移 / 复制 / 删除`；
   - 右侧属性面板随段类型切换：数据段选整数/浮点与字节序、倍率、偏置；帧长度段设宽度与 `adjust`；校验段选类型与区间；
   - 菜单「设置 → 缩放」可改界面缩放倍数（默认跟随系统 DPI）；窗口尺寸 / 缩放 / 上次打开的文件都记在 `tool.cfg`；
4. 点「保存」→ 弹窗确认协议名（默认就是当前名字，不改直接确定）→ 写入配置文件；
5. VOFA+ **约 1 秒内自动重载**（引擎每秒检查一次文件修改时间；数据源需保持有数据在收）。

默认写入路径：`<VOFA+ 安装目录>\plugins\dataengines\configurable_engine.json`。

### 2. 只读协议控件

把 `qml-widget/VofaProtoView/` 整个目录拷到 `<VOFA+ 安装目录>\plugins\widgets\`，
**重启 VOFA+**，在左侧控件抽屉里找到它（缩略图没刷新就点抽屉上方的刷新按钮），拖到画布上。
左键单击 = 立即刷新，右键 = 立即刷新 / 删除控件。

> 控件代码改动后必须重启 VOFA+ 才生效（VOFA+ 自身的机制）。

---

## 安装方法

> 只有两件事：**装协议引擎**（前置，必须）+ **装本工具箱的两个东西**（配置工具、只读控件）。
> 不想手点的话，直接跳到下面的 [🤖 让 AI 帮你装](#-让-ai-帮你装推荐)。

### 0. 前置：安装协议解析引擎（必须）

本工具箱只负责"配置/查看"，解析本身靠社区协议引擎：

1. 打开 [saltfishfly/vofa-configurable-engine](https://github.com/saltfishfly/vofa-configurable-engine) → `Code` → `Download ZIP`；
2. 解压后，把这 3 个文件复制到 `<VOFA+ 安装目录>\plugins\dataengines\`：
   - `dist\ConfigurableEngine.dll` —— 协议引擎本体
   - `configurable_engine.json` —— 协议配置（之后由本工具箱编辑）
   - `ConfigurableEngine.json` —— 协议说明（显示在 VOFA+ 的提示里）
3. 重启 VOFA+，在数据接口的「数据格式」里应能看到 `ConfigurableEngine`。

### 1. 安装配置工具

1. 把 `config-tool\` 整个目录复制到任意位置（推荐 `%USERPROFILE%\vofa-protocol-tool\`）；
   **`VofaProtocolTool.exe` 与 `VofaProtocolTool.exe.config` 必须同目录同名**（后者是高 DPI 配置，改名时要一起改）；
2. 双击 `VofaProtocolTool.exe` 即可运行（首次打开会自动指向
   `<VOFA+ 安装目录>\plugins\dataengines\configurable_engine.json`，也可在菜单「文件 → 打开配置」里换）；
3. 建议建桌面快捷方式：右键桌面 → 新建 → 快捷方式 → 目标选 `VofaProtocolTool.exe` → 完成后右键属性，
   图标选该 exe 自带的（`…\VofaProtocolTool.exe,0`）；
4. 自检（可选，不弹界面）：

   ```powershell
   .\VofaProtocolTool.exe --selftest "<VOFA+ 安装目录>\plugins\dataengines\configurable_engine.json"
   ```

   同目录会生成 `selftest.log`，里面有 JSON 往返结果和"当前配置是否读得出来"。

### 2. 安装只读协议控件

1. 把 `qml-widget\VofaProtoView\` 整个目录复制到 `<VOFA+ 安装目录>\plugins\widgets\`；
2. **重启 VOFA+**（控件代码改动必须重启才生效，这是 VOFA+ 的机制）；
3. 左侧控件抽屉里会出现 `VofaProtoView`；缩略图没刷新就点抽屉上方的刷新按钮，然后拖到画布上。

### 3. 验证安装成功

- 在配置工具里改一个字段 → 点「保存」→ 确认协议名 → VOFA+ 里 **约 1 秒内生效**（数据源要保持有数据在收）；
- 想看协议引擎日志：用 [DebugView](https://learn.microsoft.com/sysinternals/downloads/debugview) 观察
  `ConfigurableEngine: loaded <协议名> from <路径>`；
- 画布上的 `VofaProtoView` 控件应显示当前协议概要表格（左键点一下可手动刷新）。

---

## 🤖 让 AI 帮你装（推荐）

本仓库自带一键安装脚本 [`install.ps1`](install.ps1)：无交互、可重复执行、输出清晰，适合直接交给 AI Agent 跑
（Claude Code / Cursor / DSH / 任何能执行 PowerShell 的 Agent 都行）。

把下面这段整块丢给你的 AI 即可：

```text
请帮我安装 VOFA+ 自定义协议工具箱（仓库：https://github.com/ELFsay/vofa-protocol-toolkit）：

1. 克隆或下载本仓库到本地临时目录，确认里面有 config-tool\、qml-widget\、install.ps1；
2. 找到 VOFA+ 安装目录（含 vofa+.exe 的目录，通常在 C:\Program Files\VOFA+）；
3. 以 PowerShell 执行安装脚本（需要时可以加管理员权限，因为要往 VOFA+ 目录里写文件）：
   powershell -ExecutionPolicy Bypass -File install.ps1 -VofaDir "<VOFA+ 安装目录>"
4. 脚本会：把配置工具装到 %USERPROFILE%\vofa-protocol-tool\、把只读控件装到 plugins\widgets\、
   从 GitHub 下载协议引擎放进 plugins\dataengines\（已有配置不覆盖）、创建桌面快捷方式、跑一次自检；
5. 把脚本输出和 %USERPROFILE%\vofa-protocol-tool\selftest.log 贴给我；

```

脚本参数：

| 参数 | 说明 |
|---|---|
| `-VofaDir "<路径>"` | 指定 VOFA+ 安装目录；不填则自动探测（注册表 / 常见路径 / 扫一层子目录） |
| `-ToolDir "<路径>"` | 配置工具安装位置，默认 `%USERPROFILE%\vofa-protocol-tool` |
| `-SkipEngine` | 不下载协议引擎（你已经装过时用） |
| `-SkipShortcut` | 不创建桌面快捷方式 |
| `-EngineRepo <owner/repo>` | 换用别的协议引擎仓库（默认 `saltfishfly/vofa-configurable-engine`） |

> **装完这一步 AI 做不了**：请手动**重启一次 VOFA+**，然后确认两件事 ——
> ① 数据格式里有 `ConfigurableEngine`；② 控件抽屉里有 `VofaProtoView`（可拖到画布上）。

---

## 环境要求

- Windows 10 / 11（本工具用系统自带的 **.NET Framework 4.8** 运行，无需额外安装运行时）；
- VOFA+ **1.4.5** 上验证通过（协议引擎部分为社区插件，见上文来源声明）；
- 若要自己编译：只需 Windows 自带的 `csc.exe`（见下文），不需要 Qt、不需要 Visual Studio、不需要 .NET SDK。


---

## 编译

### 配置工具（无需安装 Qt / Visual Studio / .NET SDK）

```powershell
# 1) 把 DPI 清单拷到源码目录，编译时嵌入
copy src\app.manifest app.manifest

# 2) 用 Windows 自带的 .NET Framework 编译器直接编译（源码是 .txt，csc 能直接吃）
& "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319\csc.exe" `
    /nologo /target:winexe /optimize+ `
    /out:VofaProtocolTool.exe `
    /win32icon:tool.ico `
    /win32manifest:app.manifest `
    /r:System.Windows.Forms.dll /r:System.Drawing.dll `
    src\ProtocolTool.src.txt
```

> 源码用 `.txt` 保存，方便直接喂给 `csc.exe` 编译，不需要改扩展名。
> `.config` 必须与最终 exe 同名，否则高 DPI 配置不生效。

自检（不弹界面，把结果写进 `selftest.log`；会做 JSON 往返校验，并尝试读出当前配置文件）：

```powershell
.\VofaProtocolTool.exe --selftest "<VOFA+ 安装目录>\plugins\dataengines\configurable_engine.json"
```

### 只读控件

`.qml` 免编译，拷进 `plugins/widgets/` 重启 VOFA+ 即可（VOFA+ 1.4.5 内置 Qt 5.15.16，本控件只用了 QtQuick 2.12 基础组件 + `MyModules`）。

---

## 能力边界（由上游协议引擎决定）

- 校验只支持 **NONE / SUM8 / XOR8 / CRC16-MODBUS**（上游引擎里写死，不可扩展）；
- **不支持**数组解析、3 字节字段、变长解析 —— 工具栏里这些按钮只能作**占位字节**（保证后续字段偏移正确），不会输出为通道；
- 定帧方式三选一：`fixed_length` / `length_field` / `tail`（至少要有一个，否则引擎拒绝该配置）；
- 写出的 JSON 为 **UTF-8 无 BOM**（Qt 的 JSON 解析器不认 BOM）；
- 写入的 `name` 字段会出现在 VOFA+ 的调试输出里（`ConfigurableEngine: loaded <name> from <path>`），
  配 [DebugView](https://learn.microsoft.com/sysinternals/downloads/debugview) 可以确认配置加载是否成功。

---

## License

本项目采用 **MIT License**（见 `LICENSE`）。

引用的上游项目同样为 MIT：
- [saltfishfly/vofa-configurable-engine](https://github.com/saltfishfly/vofa-configurable-engine)
- [je00/Vodka](https://github.com/je00/Vodka)（`dataengines/shared`、`widgets/`）

VOFA+ 本体是固特加的软件，本仓库不包含其任何程序文件。

> 图标（`tool.ico` / `preview*.png`）基于 VOFA+ 自身图标添加角标而成，仅用于本机快速识别；
> 若原作者有异议，会立即替换为中性图标。
