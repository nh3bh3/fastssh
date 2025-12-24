# Fast Transfer - PowerShell GUI for quick folder transfer over TCP
# No external dependencies: uses built-in .NET (Windows PowerShell 5+)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.IO.Compression.FileSystem

[System.Windows.Forms.Application]::EnableVisualStyles()

$defaultPort = 9000

function Show-Message([string]$text, [string]$title = "提示", [string]$icon = "Information") {
    [System.Windows.Forms.MessageBox]::Show($text, $title, 'OK', $icon) | Out-Null
}

function Pick-Folder([System.Windows.Forms.TextBox]$targetBox) {
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    if ($dialog.ShowDialog() -eq 'OK') {
        $targetBox.Text = $dialog.SelectedPath
    }
}

function Set-Mode {
    param(
        [System.Windows.Forms.RadioButton]$sendRadio,
        [System.Windows.Forms.Control[]]$sendControls,
        [System.Windows.Forms.Control[]]$recvControls
    )
    if ($sendRadio.Checked) {
        $sendControls | ForEach-Object { $_.Enabled = $true }
        $recvControls | ForEach-Object { $_.Enabled = $false }
    }
    else {
        $sendControls | ForEach-Object { $_.Enabled = $false }
        $recvControls | ForEach-Object { $_.Enabled = $true }
    }
}

function Copy-ToStream {
    param(
        [System.IO.Stream]$input,
        [System.IO.Stream]$output
    )
    $buffer = New-Object byte[] 8192
    while (($read = $input.Read($buffer, 0, $buffer.Length)) -gt 0) {
        $output.Write($buffer, 0, $read)
    }
    $output.Flush()
}

function Start-Send {
    param(
        [string]$path,
        [int]$port,
        [System.Windows.Forms.Label]$statusLabel
    )
    if (-not (Test-Path $path)) { throw "发送路径不存在：$path" }

    $tempZip = Join-Path ([IO.Path]::GetTempPath()) 'fast_transfer.zip'
    if (Test-Path $tempZip) { Remove-Item $tempZip -Force }

    $statusLabel.Text = "正在压缩..."
    [IO.Compression.ZipFile]::CreateFromDirectory($path, $tempZip)

    $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Any, $port)
    $listener.Start()
    $statusLabel.Text = "等待连接，端口 $port"
    $client = $listener.AcceptTcpClient()
    $stream = $client.GetStream()
    $file = [IO.File]::OpenRead($tempZip)
    Copy-ToStream -input $file -output $stream
    $file.Close()
    $stream.Close()
    $client.Close()
    $listener.Stop()
    Remove-Item $tempZip -Force
    $statusLabel.Text = "发送完成"
    Show-Message "发送完成。" "完成" 'Information'
}

function Start-Receive {
    param(
        [string]$host,
        [int]$port,
        [string]$destination,
        [System.Windows.Forms.Label]$statusLabel
    )
    if (-not $host) { throw "请填写发送端 IP" }
    if (-not $destination) { throw "请选择解压目标路径" }

    if (-not (Test-Path $destination)) { New-Item -ItemType Directory -Path $destination | Out-Null }
    else {
        Get-ChildItem -Path $destination -Force | Remove-Item -Recurse -Force
    }

    $tempZip = Join-Path ([IO.Path]::GetTempPath()) 'fast_transfer_recv.zip'
    if (Test-Path $tempZip) { Remove-Item $tempZip -Force }

    $statusLabel.Text = "正在连接 $host:$port..."
    $client = [Net.Sockets.TcpClient]::new($host, $port)
    $stream = $client.GetStream()
    $file = [IO.File]::Open($tempZip, [IO.FileMode]::Create)
    Copy-ToStream -input $stream -output $file
    $file.Close()
    $stream.Close()
    $client.Close()

    $statusLabel.Text = "正在解压..."
    [IO.Compression.ZipFile]::ExtractToDirectory($tempZip, $destination)
    Remove-Item $tempZip -Force
    $statusLabel.Text = "接收完成"
    Show-Message "接收完成。" "完成" 'Information'
}

$form = New-Object System.Windows.Forms.Form
$form.Text = 'Fast Transfer'
$form.Size = New-Object System.Drawing.Size(430, 360)
$form.StartPosition = 'CenterScreen'

$sendRadio = New-Object System.Windows.Forms.RadioButton
$sendRadio.Text = '发送（压缩并发送文件夹）'
$sendRadio.Location = New-Object System.Drawing.Point(20, 15)
$sendRadio.Checked = $true
$form.Controls.Add($sendRadio)

$recvRadio = New-Object System.Windows.Forms.RadioButton
$recvRadio.Text = '接收（从远端拉取并解压）'
$recvRadio.Location = New-Object System.Drawing.Point(230, 15)
$form.Controls.Add($recvRadio)

$sendGroup = New-Object System.Windows.Forms.GroupBox
$sendGroup.Text = '发送设置'
$sendGroup.Size = New-Object System.Drawing.Size(380, 120)
$sendGroup.Location = New-Object System.Drawing.Point(20, 45)
$form.Controls.Add($sendGroup)

$sendPathLabel = New-Object System.Windows.Forms.Label
$sendPathLabel.Text = '选择要发送的文件夹：'
$sendPathLabel.Location = New-Object System.Drawing.Point(15, 30)
$sendPathLabel.AutoSize = $true
$sendGroup.Controls.Add($sendPathLabel)

$sendPathBox = New-Object System.Windows.Forms.TextBox
$sendPathBox.Location = New-Object System.Drawing.Point(15, 55)
$sendPathBox.Width = 260
$sendPathBox.ReadOnly = $true
$sendGroup.Controls.Add($sendPathBox)

$sendBrowse = New-Object System.Windows.Forms.Button
$sendBrowse.Text = '浏览...'
$sendBrowse.Location = New-Object System.Drawing.Point(285, 53)
$sendBrowse.Add_Click({ Pick-Folder $sendPathBox })
$sendGroup.Controls.Add($sendBrowse)

$sendPortLabel = New-Object System.Windows.Forms.Label
$sendPortLabel.Text = '监听端口：'
$sendPortLabel.Location = New-Object System.Drawing.Point(15, 85)
$sendPortLabel.AutoSize = $true
$sendGroup.Controls.Add($sendPortLabel)

$sendPortBox = New-Object System.Windows.Forms.TextBox
$sendPortBox.Location = New-Object System.Drawing.Point(80, 82)
$sendPortBox.Width = 70
$sendPortBox.Text = $defaultPort
$sendGroup.Controls.Add($sendPortBox)

$recvGroup = New-Object System.Windows.Forms.GroupBox
$recvGroup.Text = '接收设置'
$recvGroup.Size = New-Object System.Drawing.Size(380, 160)
$recvGroup.Location = New-Object System.Drawing.Point(20, 170)
$form.Controls.Add($recvGroup)

$recvHostLabel = New-Object System.Windows.Forms.Label
$recvHostLabel.Text = '发送端 IP：'
$recvHostLabel.Location = New-Object System.Drawing.Point(15, 30)
$recvHostLabel.AutoSize = $true
$recvGroup.Controls.Add($recvHostLabel)

$recvHostBox = New-Object System.Windows.Forms.TextBox
$recvHostBox.Location = New-Object System.Drawing.Point(90, 27)
$recvHostBox.Width = 150
$recvGroup.Controls.Add($recvHostBox)

$recvPortLabel = New-Object System.Windows.Forms.Label
$recvPortLabel.Text = '端口：'
$recvPortLabel.Location = New-Object System.Drawing.Point(15, 60)
$recvPortLabel.AutoSize = $true
$recvGroup.Controls.Add($recvPortLabel)

$recvPortBox = New-Object System.Windows.Forms.TextBox
$recvPortBox.Location = New-Object System.Drawing.Point(90, 57)
$recvPortBox.Width = 70
$recvPortBox.Text = $defaultPort
$recvGroup.Controls.Add($recvPortBox)

$recvPathLabel = New-Object System.Windows.Forms.Label
$recvPathLabel.Text = '解压目标文件夹：'
$recvPathLabel.Location = New-Object System.Drawing.Point(15, 90)
$recvPathLabel.AutoSize = $true
$recvGroup.Controls.Add($recvPathLabel)

$recvPathBox = New-Object System.Windows.Forms.TextBox
$recvPathBox.Location = New-Object System.Drawing.Point(15, 115)
$recvPathBox.Width = 260
$recvPathBox.ReadOnly = $true
$recvGroup.Controls.Add($recvPathBox)

$recvBrowse = New-Object System.Windows.Forms.Button
$recvBrowse.Text = '浏览...'
$recvBrowse.Location = New-Object System.Drawing.Point(285, 113)
$recvBrowse.Add_Click({ Pick-Folder $recvPathBox })
$recvGroup.Controls.Add($recvBrowse)

$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Text = '就绪'
$statusLabel.Location = New-Object System.Drawing.Point(20, 305)
$statusLabel.AutoSize = $true
$form.Controls.Add($statusLabel)

$startButton = New-Object System.Windows.Forms.Button
$startButton.Text = '开始传输'
$startButton.Size = New-Object System.Drawing.Size(380, 30)
$startButton.Location = New-Object System.Drawing.Point(20, 330)
$form.Controls.Add($startButton)

$sendControls = @($sendPathBox, $sendBrowse, $sendPortBox)
$recvControls = @($recvHostBox, $recvPortBox, $recvPathBox, $recvBrowse)

$sendRadio.Add_CheckedChanged({ Set-Mode $sendRadio $sendControls $recvControls })
$recvRadio.Add_CheckedChanged({ Set-Mode $sendRadio $sendControls $recvControls })

Set-Mode $sendRadio $sendControls $recvControls

$startButton.Add_Click({
    try {
        $statusLabel.Text = '处理中...'
        $portText = if ($sendRadio.Checked) { $sendPortBox.Text } else { $recvPortBox.Text }
        $port = [int]::Parse(($portText -replace '\s', ''))

        if ($sendRadio.Checked) {
            if (-not $sendPathBox.Text) { throw '请先选择要发送的文件夹。' }
            Start-Send -path $sendPathBox.Text -port $port -statusLabel $statusLabel
        }
        else {
            if (-not $recvPathBox.Text) { throw '请先选择解压目标文件夹。' }
            Start-Receive -host $recvHostBox.Text -port $port -destination $recvPathBox.Text -statusLabel $statusLabel
        }
    }
    catch {
        $statusLabel.Text = '出错'
        Show-Message $_.Exception.Message '错误' 'Error'
    }
})

$form.Add_Shown({ $form.Activate() })
[System.Windows.Forms.Application]::Run($form)
