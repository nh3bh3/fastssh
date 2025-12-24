# fastssh

提供两种可选方式在两台 Windows 电脑间快速传输大量文件/文件夹。

## 方案一：PowerShell（免安装推荐）

无需额外依赖，Windows 自带 PowerShell 即可运行。

1. 双击或右键使用“使用 PowerShell 运行”打开 `fast_transfer.ps1`。
2. 在弹出的 GUI 中选择 **发送** 或 **接收** 角色。
   - 发送端：点击“浏览”选择要传输的文件夹，可修改监听端口（默认 9000），点击“开始传输”后自动压缩并等待连接；
   - 接收端：填写发送端 IP/端口，选择解压目标文件夹，点击“开始传输”后自动连接、接收并解压；
   - 窗口右上角关闭即可退出脚本。
3. 确保双方在同一网络，且防火墙放行所用端口。

## 方案二：AutoHotkey（便携版，可直接点击运行）

仓库内已附带便携版解释器 `AutoHotkeyU64.exe` 与启动脚本 `run_fast_transfer.cmd`，无需额外安装即可点击运行：

1. 将仓库中的 `fast_transfer.ahk`、`AutoHotkeyU64.exe`、`run_fast_transfer.cmd` 同目录放到两台电脑。
2. 直接双击 `run_fast_transfer.cmd` 即可启动 AHK GUI（鼠标宏等工具也可直接调用该 CMD 文件）。
3. 如果你电脑已经安装了 AutoHotkey v1，也可以继续双击 `fast_transfer.ahk` 运行。

## 注意事项

- 传输通过 TCP 点对点，数据只在内网中流转，无需额外服务端。
- 发送端会在 `%TEMP%` 目录下生成临时 zip 文件并在传输完毕后删除。
- 如需重复接收，确保目标目录无被占用文件，避免解压覆盖失败。
