; 简易 GUI 的 AHK 数据传输脚本（无需额外安装第三方依赖）
#NoEnv
#SingleInstance force
SendMode Input
SetWorkingDir %A_ScriptDir%

global Mode := "send"
global SendPath := ""
global ReceivePath := ""
global DefaultPort := "9000"

Gui, Font, s10
Gui, Add, Text,, 角色：
Gui, Add, Radio, vModeRadioSend gToggleMode Checked, 发送（压缩并发送文件夹）
Gui, Add, Radio, vModeRadioRecv gToggleMode, 接收（从远端拉取并解压）
Gui, Add, Text, ym, 

; 发送端区域
Gui, Add, GroupBox, xm w380 h130 Section, 发送设置
Gui, Add, Text, xs+15 ys+25, 选择要发送的文件夹：
Gui, Add, Edit, vSendPathEdit xs+15 yp+20 w260 ReadOnly
Gui, Add, Button, xs+280 yp-2 gPickSend, 浏览...
Gui, Add, Text, xs+15 yp+40, 监听端口：
Gui, Add, Edit, vSendPort xs+80 yp-5 w70, %DefaultPort%

; 接收端区域
Gui, Add, GroupBox, xm w380 h160 Section vRecvGroup, 接收设置
Gui, Add, Text, xs+15 ys+25, 发送端 IP：
Gui, Add, Edit, vRecvHost xs+90 yp-5 w150
Gui, Add, Text, xs+15 yp+30, 端口：
Gui, Add, Edit, vRecvPort xs+90 yp-5 w70, %DefaultPort%
Gui, Add, Text, xs+15 yp+30, 解压目标文件夹：
Gui, Add, Edit, vRecvPathEdit xs+15 yp+20 w260 ReadOnly
Gui, Add, Button, xs+280 yp-2 gPickRecv, 浏览...

Gui, Add, Button, xm w380 gStartTransfer, 开始传输
Gui, Show, , Fast Transfer
Gosub, ToggleMode
Return

GuiClose:
GuiEscape:
    ExitApp

ToggleMode:
    Gui, Submit, NoHide
    GuiControlGet, ModeRadioSend
    Mode := ModeRadioSend ? "send" : "recv"
    if (Mode = "send")
    {
        GuiControl, Enable, SendPathEdit
        GuiControl, Enable, SendPort
        GuiControl, Enable, PickSend
        GuiControl, Disable, RecvHost
        GuiControl, Disable, RecvPort
        GuiControl, Disable, RecvPathEdit
        GuiControl, Disable, PickRecv
    }
    else
    {
        GuiControl, Disable, SendPathEdit
        GuiControl, Disable, SendPort
        GuiControl, Disable, PickSend
        GuiControl, Enable, RecvHost
        GuiControl, Enable, RecvPort
        GuiControl, Enable, RecvPathEdit
        GuiControl, Enable, PickRecv
    }
Return

PickSend:
    FileSelectFolder, chosen, , 3, 选择要发送的文件夹
    if (chosen != "")
    {
        SendPath := chosen
        GuiControl,, SendPathEdit, %SendPath%
    }
Return

PickRecv:
    FileSelectFolder, chosen, , 3, 选择解压后的目标文件夹
    if (chosen != "")
    {
        ReceivePath := chosen
        GuiControl,, RecvPathEdit, %ReceivePath%
    }
Return

StartTransfer:
    Gui, Submit, NoHide
    GuiControlGet, SendPort
    GuiControlGet, RecvPort
    GuiControlGet, RecvHost
    GuiControlGet, SendPathEdit
    GuiControlGet, RecvPathEdit
    SendPath := SendPathEdit
    ReceivePath := RecvPathEdit

    if (Mode = "send")
    {
        if (SendPath = "")
        {
            MsgBox, 48, 提示, 请先选择要发送的文件夹。
            Return
        }
        if (SendPort = "")
        {
            SendPort := DefaultPort
            GuiControl,, SendPort, %SendPort%
        }

        TrayTip, Fast Transfer, 正在压缩并等待连接..., 5, 1
        powershellCommand := "Add-Type -AssemblyName 'System.IO.Compression.FileSystem';"
            . " $source='" SendPath "';"
            . " $zip=Join-Path $env:TEMP 'fast_transfer.zip';"
            . " if(Test-Path $zip){Remove-Item $zip -Force};"
            . " [IO.Compression.ZipFile]::CreateFromDirectory($source,$zip);"
            . " $listener=[Net.Sockets.TcpListener]::new([Net.IPAddress]::Any," SendPort ");"
            . " $listener.Start();"
            . " Write-Host '等待连接，端口 " SendPort "';"
            . " $client=$listener.AcceptTcpClient();"
            . " $stream=$client.GetStream();"
            . " $file=[IO.File]::OpenRead($zip);"
            . " $file.CopyTo($stream);"
            . " $stream.Close();$client.Close();$listener.Stop();"
            . " Remove-Item $zip -Force;"
            . " Write-Host '传输完成';"

        RunWait, % "powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -Command """ powershellCommand """",, Hide
        TrayTip
        MsgBox, 64, 完成, 发送完成。
    }
    else
    {
        if (RecvHost = "")
        {
            MsgBox, 48, 提示, 请填写发送端 IP。
            Return
        }
        if (ReceivePath = "")
        {
            MsgBox, 48, 提示, 请先选择解压目标文件夹。
            Return
        }
        if (RecvPort = "")
        {
            RecvPort := DefaultPort
            GuiControl,, RecvPort, %RecvPort%
        }

        TrayTip, Fast Transfer, 正在连接并接收数据..., 5, 1
        powershellCommand := "Add-Type -AssemblyName 'System.IO.Compression.FileSystem';"
            . " $destFolder='" ReceivePath "';"
            . " $zip=Join-Path $env:TEMP 'fast_transfer_recv.zip';"
            . " if(Test-Path $zip){Remove-Item $zip -Force};"
            . " $client=[Net.Sockets.TcpClient]::new('" RecvHost "'," RecvPort ");"
            . " $stream=$client.GetStream();"
            . " $file=[IO.File]::OpenWrite($zip);"
            . " $buffer=New-Object byte[] 8192;"
            . " while(($read=$stream.Read($buffer,0,$buffer.Length)) -gt 0){$file.Write($buffer,0,$read)};"
            . " $file.Close();$stream.Close();$client.Close();"
            . " if(Test-Path $destFolder){Remove-Item -Recurse -Force (Join-Path $destFolder '*')};"
            . " [IO.Compression.ZipFile]::ExtractToDirectory($zip,$destFolder);"
            . " Remove-Item $zip -Force;"
            . " Write-Host '接收完成';"

        RunWait, % "powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -Command """ powershellCommand """",, Hide
        TrayTip
        MsgBox, 64, 完成, 接收完成。
    }
Return
