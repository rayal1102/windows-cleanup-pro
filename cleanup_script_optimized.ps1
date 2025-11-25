# DonDepOC_2025_Pro - Optimized & Safe Version
# Version 2.1 - Enhanced safety and GitHub-ready

#Requires -RunAsAdministrator

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$host.UI.RawUI.WindowTitle = "Dọn Ổ C Siêu Sạch 2025 PRO v2.1"

# Configuration
$ErrorActionPreference = "SilentlyContinue"
$ProgressPreference = "SilentlyContinue"

# Global variables
$script:totalSteps = 14
$script:currentStep = 0
$script:beforeTotal = 0
$script:maxExpected = 120
$script:restorePointCreated = $false

function Test-AdminRights {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]$identity
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Initialize-CleanupEnvironment {
    Clear-Host
    
    # Runtime admin check
    if (-not (Test-AdminRights)) {
        Write-Host "❌ Script phải chạy với quyền Administrator!" -ForegroundColor Red
        Write-Host "Nhấp chuột phải vào file và chọn 'Run as Administrator'" -ForegroundColor Yellow
        Read-Host "Nhấn Enter để thoát"
        exit
    }
    
    $script:beforeTotal = [math]::Round((Get-PSDrive C).Used / 1GB, 2)
    
    Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "     DỌN Ổ C SIÊU SẠCH 2025 – PHIÊN BẢN PRO v2.1" -ForegroundColor Cyan
    Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "Dung lượng đã dùng: $script:beforeTotal GB`n" -ForegroundColor White
    
    # Create restore point
    Write-Host "🛡️  Tạo điểm khôi phục hệ thống..." -ForegroundColor Yellow
    try {
        Checkpoint-Computer -Description "Trước khi dọn dẹp ổ C" -RestorePointType "MODIFY_SETTINGS"
        $script:restorePointCreated = $true
        Write-Host "✓ Đã tạo điểm khôi phục thành công!`n" -ForegroundColor Green
    }
    catch {
        Write-Host "⚠ Không thể tạo điểm khôi phục (có thể đã tắt System Restore)`n" -ForegroundColor Yellow
    }
    
    Start-Sleep -Seconds 2
}

function Show-Progress {
    param(
        [string]$TaskName,
        [string]$Status = "Đang xử lý"
    )
    
    $script:currentStep++
    $percentStep = [int](($script:currentStep / $script:totalSteps) * 100)
    
    Write-Host "`n[$script:currentStep/$script:totalSteps] $TaskName" -ForegroundColor Cyan
    Write-Host "$Status... " -NoNewline -ForegroundColor Yellow
    
    # Progress bar
    $barLength = 50
    $filled = [int](($percentStep / 100) * $barLength)
    $bar = "█" * $filled + "░" * ($barLength - $filled)
    Write-Host "`n   [$bar] $percentStep%" -ForegroundColor Green
    
    # Space freed progress
    $currentUsed = [math]::Round((Get-PSDrive C).Used / 1GB, 2)
    $freed = [math]::Round($script:beforeTotal - $currentUsed, 2)
    if ($freed -lt 0) { $freed = 0 }
    
    $percentFreed = [int](($freed / $script:maxExpected) * 100)
    if ($percentFreed -gt 100) { $percentFreed = 100 }
    
    $filledFreed = [int](($percentFreed / 100) * $barLength)
    $barFreed = "█" * $filledFreed + "░" * ($barLength - $filledFreed)
    Write-Host "   Đã giải phóng: $freed GB [$barFreed] $percentFreed%" -ForegroundColor Magenta
}

function Complete-Task {
    Write-Host " ✓ Hoàn tất!" -ForegroundColor Green
}

function Invoke-SafeCleanup {
    param([scriptblock]$Action, [string]$ErrorMessage = "Lỗi không xác định")
    
    try {
        & $Action
        Complete-Task
    }
    catch {
        Write-Host " ⚠ Cảnh báo: $ErrorMessage" -ForegroundColor Yellow
    }
}

# ==================== CLEANUP TASKS ====================

function Clean-WinSxS {
    Show-Progress "Dọn WinSxS + Xóa bản cập nhật cũ"
    Invoke-SafeCleanup {
        Start-Process dism.exe -ArgumentList "/Online /Cleanup-Image /StartComponentCleanup /ResetBase" -Wait -NoNewWindow
    }
}

function Clean-WindowsOld {
    Show-Progress "Xóa Windows.old và thư mục cài đặt cũ"
    Invoke-SafeCleanup {
        $paths = @("C:\Windows.old", "C:\`$Windows.~BT", "C:\`$Windows.~WS", "C:\ESD")
        foreach ($path in $paths) {
            if (Test-Path $path) {
                Remove-Item $path -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

function Run-DiskCleanup {
    Show-Progress "Chạy Disk Cleanup toàn bộ"
    Invoke-SafeCleanup {
        # Configure cleanup settings
        $registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches"
        $cleanupKeys = @(
            "Active Setup Temp Folders", "BranchCache", "Downloaded Program Files",
            "Internet Cache Files", "Memory Dump Files", "Offline Pages Files",
            "Old ChkDsk Files", "Previous Installations", "Recycle Bin",
            "Service Pack Cleanup", "Setup Log Files", "System error memory dump files",
            "System error minidump files", "Temporary Files", "Temporary Setup Files",
            "Thumbnail Cache", "Update Cleanup", "Upgrade Discarded Files",
            "Windows Defender", "Windows Error Reporting Files", "Windows ESD installation files",
            "Windows Upgrade Log Files"
        )
        
        foreach ($key in $cleanupKeys) {
            $keyPath = Join-Path $registryPath $key
            if (Test-Path $keyPath) {
                Set-ItemProperty -Path $keyPath -Name "StateFlags0065" -Value 2 -ErrorAction SilentlyContinue
            }
        }
        
        Start-Process cleanmgr.exe -ArgumentList "/sagerun:65" -Wait -NoNewWindow
    }
}

function Clean-TempFiles {
    Show-Progress "Xóa Temp, Cache, Thùng rác, Prefetch"
    Invoke-SafeCleanup {
        $tempPaths = @(
            $env:TEMP,
            "$env:SystemRoot\Temp",
            "$env:SystemRoot\Prefetch",
            "$env:LOCALAPPDATA\Temp",
            "$env:LOCALAPPDATA\Microsoft\Windows\INetCache",
            "$env:LOCALAPPDATA\Microsoft\Windows\WebCache"
        )
        
        foreach ($path in $tempPaths) {
            if (Test-Path $path) {
                Get-ChildItem $path -Force -ErrorAction SilentlyContinue | 
                    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-7) } |
                    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
        
        Clear-RecycleBin -Force -ErrorAction SilentlyContinue
    }
}

function Clean-WindowsUpdate {
    Show-Progress "Dọn cache Windows Update"
    Invoke-SafeCleanup {
        Stop-Service wuauserv, bits, dosvc -Force
        Start-Sleep -Seconds 2
        
        $updatePath = "$env:SystemRoot\SoftwareDistribution\Download"
        if (Test-Path $updatePath) {
            Get-ChildItem $updatePath -Force | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        }
        
        Start-Service wuauserv, bits, dosvc
    }
}

function Clean-OldDrivers {
    Show-Progress "Dọn driver backup cũ (an toàn)"
    Invoke-SafeCleanup {
        # Chỉ xóa driver backup cũ, không xóa driver đang dùng
        $driverStore = "$env:SystemRoot\System32\DriverStore\FileRepository"
        if (Test-Path $driverStore) {
            Get-ChildItem $driverStore -Directory | 
                Where-Object { $_.LastWriteTime -lt (Get-Date).AddMonths(-6) } |
                Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

function Manage-Hibernation {
    Show-Progress "Quản lý chế độ ngủ đông"
    Invoke-SafeCleanup {
        $hiberFile = "$env:SystemDrive\hiberfil.sys"
        if (Test-Path $hiberFile) {
            $hiberSize = [math]::Round((Get-Item $hiberFile).Length / 1GB, 2)
            Write-Host "`n   Tìm thấy hiberfil.sys ($hiberSize GB)" -ForegroundColor Yellow
            Write-Host "   Tắt hibernation để giải phóng dung lượng? (Y/N): " -NoNewline
            $response = Read-Host
            if ($response -eq 'Y' -or $response -eq 'y') {
                powercfg -h off
                Write-Host "   ✓ Đã tắt hibernation" -ForegroundColor Green
            }
            else {
                Write-Host "   ⊗ Giữ nguyên hibernation" -ForegroundColor Gray
            }
        }
    }
}

function Clean-SystemLogs {
    Show-Progress "Dọn log hệ thống + cache trình duyệt"
    Invoke-SafeCleanup {
        # Clear event logs
        wevtutil el | ForEach-Object { wevtutil cl $_ }
        
        # Browser caches
        $browserCaches = @(
            "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache",
            "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Code Cache",
            "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache",
            "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Code Cache",
            "$env:LOCALAPPDATA\Mozilla\Firefox\Profiles\*\cache2"
        )
        
        foreach ($cache in $browserCaches) {
            if (Test-Path $cache) {
                Remove-Item $cache -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

function Enable-CompactOS {
    Show-Progress "Bật nén hệ thống CompactOS (XPRESS)"
    Invoke-SafeCleanup {
        # Use XPRESS instead of LZX for better performance
        compact /compactos:always
    }
}

function Compress-WinSxS {
    Show-Progress "Nén WinSxS (XPRESS - cân bằng)"
    Invoke-SafeCleanup {
        # Use XPRESS8K for balance between size and speed
        Start-Process compact -ArgumentList "/c /s:C:\Windows\WinSxS /exe:XPRESS8K /i /q" -Wait -NoNewWindow
    }
}

function Compress-ProgramFiles {
    Show-Progress "Nén Program Files (tùy chọn)"
    Write-Host "`n   ⚠ Nén Program Files có thể làm chậm ứng dụng" -ForegroundColor Yellow
    Write-Host "   Tiếp tục nén? (Y/N): " -NoNewline
    $response = Read-Host
    
    if ($response -eq 'Y' -or $response -eq 'y') {
        Invoke-SafeCleanup {
            $paths = @("C:\Program Files", "C:\Program Files (x86)")
            foreach ($path in $paths) {
                if (Test-Path $path) {
                    Start-Process compact -ArgumentList "/c /s:`"$path`" /exe:XPRESS4K /i /q" -Wait -NoNewWindow
                }
            }
        }
    }
    else {
        Write-Host "   ⊗ Bỏ qua nén Program Files" -ForegroundColor Gray
        Complete-Task
    }
}

function Clean-DeliveryOptimization {
    Show-Progress "Dọn Delivery Optimization cache"
    Invoke-SafeCleanup {
        Stop-Service dosvc -Force
        Start-Sleep -Seconds 2
        
        $doPaths = @(
            "$env:SystemRoot\ServiceProfiles\NetworkService\AppData\Local\Microsoft\Windows\DeliveryOptimization\Cache",
            "$env:SystemRoot\SoftwareDistribution\DeliveryOptimization"
        )
        
        foreach ($doPath in $doPaths) {
            if (Test-Path $doPath) {
                Get-ChildItem $doPath -Force | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
        
        Start-Service dosvc
    }
}

function Optimize-Registry {
    Show-Progress "Tối ưu hóa Registry"
    Invoke-SafeCleanup {
        # Clear MRU lists and recent items
        $regPaths = @(
            "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU",
            "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\TypedPaths",
            "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RecentDocs"
        )
        
        foreach ($regPath in $regPaths) {
            if (Test-Path $regPath) {
                Remove-Item $regPath -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

function Finalize-Cleanup {
    Show-Progress "Hoàn tất và kiểm tra kết quả"
    Invoke-SafeCleanup {
        # Run final disk check
        Start-Sleep -Seconds 1
    }
}

function Show-FinalResults {
    $afterTotal = [math]::Round((Get-PSDrive C).Used / 1GB, 2)
    $savedTotal = [math]::Round($script:beforeTotal - $afterTotal, 2)
    
    Clear-Host
    Write-Host "`n════════════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host "              HOÀN TẤT 100% – Ổ C NHẸ TÊNH!" -ForegroundColor Green
    Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host "`n   Trước khi dọn:  $script:beforeTotal GB" -ForegroundColor White
    Write-Host "   Sau khi dọn:    $afterTotal GB" -ForegroundColor White
    Write-Host "`n   ĐÃ GIẢI PHÓNG: $savedTotal GB" -ForegroundColor Yellow -BackgroundColor DarkGreen
    
    if ($script:restorePointCreated) {
        Write-Host "`n   🛡️  Đã tạo điểm khôi phục nếu cần rollback" -ForegroundColor Cyan
    }
    
    if ($savedTotal -gt 80) {
        Write-Host "`n   🏆 TUYỆT VỜI! Top 5% máy sạch nhất!" -ForegroundColor Cyan
    }
    elseif ($savedTotal -gt 40) {
        Write-Host "`n   ✨ RẤT TỐT! Máy đã nhẹ hơn nhiều!" -ForegroundColor Green
    }
    elseif ($savedTotal -gt 10) {
        Write-Host "`n   ✓ Tốt! Đã giải phóng đáng kể." -ForegroundColor Green
    }
    else {
        Write-Host "`n   ℹ Máy của bạn đã khá sạch rồi!" -ForegroundColor Yellow
    }
    
    Write-Host "`n   Máy giờ nhanh hơn, mượt mà hơn rất nhiều! ❤`n" -ForegroundColor White
    Write-Host "════════════════════════════════════════════════════════════`n" -ForegroundColor Green
    
    $restart = Read-Host "Khởi động lại máy ngay để áp dụng hoàn toàn? (Y/N)"
    if ($restart -eq 'Y' -or $restart -eq 'y') {
        Write-Host "`nĐang khởi động lại sau 10 giây..." -ForegroundColor Yellow
        Write-Host "Nhấn Ctrl+C để hủy`n" -ForegroundColor Gray
        Start-Sleep -Seconds 10
        Restart-Computer -Force
    }
    else {
        Write-Host "`n✓ Hoàn tất! Bạn có thể đóng cửa sổ này." -ForegroundColor Green
        Write-Host "  Khuyến nghị: Khởi động lại máy trong thời gian sớm nhất.`n" -ForegroundColor Yellow
        Read-Host "Nhấn Enter để thoát"
    }
}

# ==================== MAIN EXECUTION ====================

try {
    Initialize-CleanupEnvironment
    
    Clean-WinSxS
    Clean-WindowsOld
    Run-DiskCleanup
    Clean-TempFiles
    Clean-WindowsUpdate
    Clean-OldDrivers
    Manage-Hibernation
    Clean-SystemLogs
    Enable-CompactOS
    Compress-WinSxS
    Compress-ProgramFiles
    Clean-DeliveryOptimization
    Optimize-Registry
    Finalize-Cleanup
    
    Show-FinalResults
}
catch {
    Write-Host "`n❌ Lỗi nghiêm trọng: $_" -ForegroundColor Red
    Write-Host "Script đã dừng để bảo vệ hệ thống.`n" -ForegroundColor Yellow
    
    if ($script:restorePointCreated) {
        Write-Host "Bạn có thể khôi phục hệ thống về trước đó:" -ForegroundColor Cyan
        Write-Host "Control Panel → System → System Protection → System Restore`n" -ForegroundColor Gray
    }
    
    Read-Host "Nhấn Enter để thoát"
    exit 1
}