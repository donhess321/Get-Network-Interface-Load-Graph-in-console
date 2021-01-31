# Draw a graph of the Network interface transfer rate
# The initial start up takes about 5 seconds.  Afterward, refresh is fast.
# Written if PS v5.1, might work on PS v2 as it's pretty straight forward.
#
#   1M S: }}}}}}}                   R: {{{{{{{{{{                Interface Name
#   1M S: }                         R: {                         Interface Name

#Set-StrictMode -Version latest -Verbose
#$ErrorActionPreference = 'Stop'
#$PSDefaultParameterValues['*:ErrorAction']='Stop'

function Get-NetInterfaceLoadGraph( [bool] $EnableColor=$false ) {
    $htNetSpeedNumToString = @{}
    $htNetSpeedNumToString[1000000] = '1M'
    $htNetSpeedNumToString['1000000'] = '1M'
    $htNetSpeedNumToString[10000000] = '10M'
    $htNetSpeedNumToString['10000000'] = '10M'
    $htNetSpeedNumToString[100000000] = '100M'
    $htNetSpeedNumToString['100000000'] = '100M'
    $htNetSpeedNumToString[1000000000] = '1G'
    $htNetSpeedNumToString['1000000000'] = '1G'
    $htNetSpeedNumToString[10000000000] = '10G'
    $htNetSpeedNumToString['10000000000'] = '10G'
    $htNetSpeedNumToString[25000000000] = '25G'
    $htNetSpeedNumToString['25000000000'] = '25G'
    $htNetSpeedNumToString[40000000000] = '40G'
    $htNetSpeedNumToString['40000000000'] = '40G'
    function funcNetSpeedNumToString( $Number ) {
        # Input:   Integer or string
        # Returns: String between 2 and 4 characters
        # Note:  Needs htNetSpeedNumToString defined outside this function
        $sReturned = $htNetSpeedNumToString[$Number]
        if ( $null -eq $sReturned ) {
            $sReturned = '--'
        }
        return $sReturned
    }
    function funcSetNetInterfaceGraphScale( $iBitRate ) {
        switch ( $iBitRate ) {
            {(0 -le $_) -and ($_ -le 1000000) } { # 0-1M
                return 1000000
                break
            }
            {(1000000 -lt $_ ) -and ($_ -le 10000000)} { # 1M-10M
                return 10000000
                break
            }
            {(10000000 -lt $_ ) -and ($_ -le 100000000)} { # 10M-100M
                return 100000000
                break
            }
            {(100000000 -lt $_ ) -and ($_ -le 1000000000)} { # 100M-1G
                return 1000000000
                break
            }
            {(1000000000 -lt $_ ) -and ($_ -le 10000000000)} { # 1G-10G
                return 10000000000
                break
            }
            {(10000000000 -lt $_ ) -and ($_ -le 25000000000)} { # 10G-25G
                return 25000000000
                break
            }
            {(25000000000 -lt $_ ) -and ($_ -le 40000000000)} { # 25G-40G
                return 40000000000
                break
            }
            default {
                $sOut1 = @('$iBitRate is:',$iBitRate,$iBitRate.gettype()) -join ''
                Write-Host $sOut1
                throw [System.ArgumentException] 'iBitRate input is not in any of the available ranges'
            }
        }
    } # End funcSetNetInterfaceGraphScale
    function GetNetInterfaceData( [array] $aPreviousCaptures=@() ) {
        #$aNetCntr = @(Get-WmiObject -Namespace "Root\CIMv2" -Computer . -Class Win32_PerfFormattedData_Tcpip_NetworkInterface)
        $aNetCntr = @(Get-WmiObject -Namespace "Root\CIMv2" -Computer . -Class Win32_PerfRawData_Tcpip_NetworkInterface)
        $iLen = $aNetCntr.Length
        for ( $i=0; $i -lt $iLen; $i++ ) {
            # BytesReceivedPersec             : 2818
            # BytesSentPersec                 : 11545
            # BytesTotalPersec                : 14364
            # CurrentBandwidth                : 100,000,000
            # Name                            : Broadcom BCM5708C NetXtreme II GigE [NDIS VBD Client]
            $oReturned = '' | Select 'Name','SentTicks','RecTicks','GraphScale','CapturedData'
            $CapturedData = '' | Select 'Name','BytesSentPersec','BytesReceivedPersec','Timestamp_Sec'
            #$iCurrentTimeSec = ($aNetCntr[$i].Timestamp_Sys100NS/10000) # UInt64
            $iCurrentTimeSec = ($aNetCntr[$i].Timestamp_Sys100NS/10000000) # UInt64
            $CapturedData.BytesSentPersec, $CapturedData.BytesReceivedPersec = $aNetCntr[$i].BytesSentPersec, $aNetCntr[$i].BytesReceivedPersec
            $CapturedData.Timestamp_Sec = $iCurrentTimeSec
            $CapturedData.Name = $aNetCntr[$i].Name
            # Create initial counter run if nothing passed in
            if ( -not $aPreviousCaptures ) {
                $oReturned.Name = $aNetCntr[$i].Name
                $oReturned.SentTicks = 0
                $oReturned.RecTicks = 0
                $oReturned.GraphScale = funcSetNetInterfaceGraphScale 0
                $oReturned.CapturedData = $CapturedData
                ,$oReturned
                continue  # Next in for loop
            }
            # Match up with previous interface capture
            $aPreviousCaptures | ForEach-Object {
                if ( $_.Name -eq $aNetCntr[$i].Name ) {
                    $oPreviousCapture = $_
                }
            }
            #Write-Host '$aPreviousCaptures is:' $aPreviousCaptures
            # Current bytes - bytes last read, multiplied by 8 to get bits, divided by time difference in seconds
            $iSentBitsPersec = (($aNetCntr[$i].BytesSentPersec - $oPreviousCapture.BytesSentPersec)*8)/($iCurrentTimeSec - $oPreviousCapture.Timestamp_Sec)
            $iRecBitsPersec = (($aNetCntr[$i].BytesReceivedPersec - $oPreviousCapture.BytesReceivedPersec)*8)/($iCurrentTimeSec - $oPreviousCapture.Timestamp_Sec)

            $iMaxValue = [math]::Max($iSentBitsPersec, $iRecBitsPersec)
            if ( ($null -eq $iMaxValue) -or ($iMaxValue -lt 0) ) {
                $iMaxValue = 0
            }
            $iGraphScale = funcSetNetInterfaceGraphScale $iMaxValue
            $iGraphCharSize = 25

            # Divide bits/sec by interface scaling window (gives a decimal), multiply by 25 to get number of characters for the graph),
            #    add 0.48 to get something to show on screen most of time, round to double, cas to integer
            $dblTemp1 = ($iSentBitsPersec / $iGraphScale) * $iGraphCharSize #+0.25
            $iSentTicks = [int] ([math]::Round($dblTemp1,[midpointrounding]::AwayFromZero))
            if ( $iSentTicks -gt $iGraphCharSize ) {
                $iSentTicks = $iGraphCharSize
            }
            $dblTemp2 = (($iRecBitsPersec / $iGraphScale) * $iGraphCharSize) #+0.25
            $iRecTicks = [int] ([math]::Round($dblTemp2,[midpointrounding]::AwayFromZero))
            if ( $iRecTicks -gt $iGraphCharSize ) {
                $iRecTicks = $iGraphCharSize
            }
            #$sOut1 = @($aNetCntr[$i].BytesSentPersec,$oPreviousCapture.BytesSentPersec,$aNetCntr[$i].BytesReceivedPersec,$oPreviousCapture.BytesReceivedPersec) -join ' | '
            #Out-File -Append -FilePath 'log.txt' -InputObject $sOut1
            #$sOut1 = @($iSentBitsPersec,$dblTemp1,$iRecBitsPersec,$dblTemp2,$aNetCntr[$i].Name) -join ' : '
            #Out-File -Append -FilePath 'log.txt' -InputObject $sOut1
            $oReturned.Name = $aNetCntr[$i].Name
            $oReturned.SentTicks = $iSentTicks
            $oReturned.RecTicks = $iRecTicks
            $oReturned.GraphScale = $iGraphScale
            $oReturned.CapturedData = $CapturedData
            ,$oReturned
        } # End for loop
    } # End GetNetInterfaceData
    function FormatNetInterfaceGraphData( $oCounter ) {
        # Input: Array from GetNetInterfaceData function
        # Shooting for 25+25 chars for each graph tick marks, 70 chars for entire line.
        #   1M S: }}}}}}}                   R: {{{{{{{{{{                Interface Name
        $iGraphCharSize = 25
        $iSendTicks =  $oCounter.SentTicks
        $iSendTicksBlanks = $iGraphCharSize - $iSendTicks
        $iRecTicks =  $oCounter.RecTicks
        $iRecTicksBlanks = $iGraphCharSize - $iRecTicks
        if ( $oCounter.Name.Length -ge 18 ) {
            $sNetInterfaceName = $oCounter.Name.Substring(0,18)
        } else {
            $sNetInterfaceName = $oCounter.Name.Substring(0,$oCounter.Name.Length)
        }
        $sScale = (funcNetSpeedNumToString $oCounter.GraphScale).PadLeft(4,' ')
        ,@($sScale,' S: ',('}'*$iSendTicks),(' '*$iSendTicksBlanks),' R: ',('{'*$iRecTicks),(' '*$iRecTicksBlanks),'  ',$sNetInterfaceName)
    }
    function WriteColor($aText, $aColors) {
        # https://stackoverflow.com/questions/2688547/multiple-foreground-colors-in-powershell-in-one-command
        $iLen = $aText.Length
        for ( $i=0; $i -lt $iLen; $i++ ) {
            Write-Host $aText[$i] -Foreground $aColors[$i] -NoNewLine
        }
        Write-Host
    }
    function WriteNetInterfaceGraph( [array] $aPreviousCaptures1=@(), [bool] $EnableColor=$false ) {
        $aNetInfo = @(GetNetInterfaceData $aPreviousCaptures1) # Array of objects
        $aColors = @('White','White','Red','White','White','Green','White','White','White')
        Clear
        foreach ( $oInfo in $aNetInfo ) {
            $aPreviousCaptures1 += $oInfo.CapturedData
            $aSingleGraph = FormatNetInterfaceGraphData $oInfo
            if ( $EnableColor ) {
                WriteColor $aSingleGraph $aColors
            } else {
                Write-Host ($aSingleGraph -join '')
            }
        }
        return ,$aPreviousCaptures1
    }
    $aPreviousCaptures1=@()
    while ($true) {
        $aPreviousCaptures1 = WriteNetInterfaceGraph $aPreviousCaptures1 $EnableColor
        Sleep -Milliseconds 900
    }
}
