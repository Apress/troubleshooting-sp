$pathToULSViewer = “D:\Toolbox\UlsViewer.exe”

if ($args[0] -ne $null) {

    if ($args[1] -ne $null) {

        $outputPath = $args[1]

    } else {

        $outputPath = Join-Path $Pwd.Path $(“byCorrelation_” + $args[0] + “.log”)

    }

    Merge-SPLogFile -Path $outputPath -overwrite -Correlation $args[0] | Out-Null 

    if (Test-Path $outputPath) { Invoke-Expression “$pathToULSViewer $outputPath” }

    else { Write-Warning (“=== Found No Matching Events for this Correlation ===”) }

} else { Write-Warning (“=== No CorrelationId Provided ===”