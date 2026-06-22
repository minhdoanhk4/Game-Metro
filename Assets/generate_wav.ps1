param($FilePath, $Freq1, $Freq2, $DurationSec, $Type)
$sampleRate = 44100
$numSamples = [int]($sampleRate * $DurationSec)
$bytesPerSample = 2
$channels = 1
$dataSize = $numSamples * $bytesPerSample * $channels
$fileSize = 36 + $dataSize

$stream = [System.IO.File]::Create($FilePath)
$writer = New-Object System.IO.BinaryWriter($stream)

$writer.Write([char[]]'RIFF')
$writer.Write([int]$fileSize)
$writer.Write([char[]]'WAVE')

$writer.Write([char[]]'fmt ')
$writer.Write([int]16)
$writer.Write([int16]1)
$writer.Write([int16]$channels)
$writer.Write([int]$sampleRate)
$writer.Write([int]($sampleRate * $channels * $bytesPerSample))
$writer.Write([int16]($channels * $bytesPerSample))
$writer.Write([int16]($bytesPerSample * 8))

$writer.Write([char[]]'data')
$writer.Write([int]$dataSize)

for ($i = 0; $i -lt $numSamples; $i++) {
    $t = $i / $sampleRate
    $val = 0
    if ($Type -eq 'horn') {
        $val = ([math]::Sin(2 * [math]::PI * $Freq1 * $t) + [math]::Sin(2 * [math]::PI * $Freq2 * $t)) * 0.3
    } elseif ($Type -eq 'beep') {
        if (($t % 0.5) -lt 0.2) {
            $val = [math]::Sin(2 * [math]::PI * $Freq1 * $t) * 0.5
        }
    } elseif ($Type -eq 'noise') {
        $val = (Get-Random -Minimum -100 -Maximum 100) / 100.0 * 0.2
    }
    
    $shortVal = [int]($val * 32767)
    if ($shortVal -gt 32767) { $shortVal = 32767 }
    if ($shortVal -lt -32768) { $shortVal = -32768 }
    $writer.Write([int16]$shortVal)
}

$writer.Close()
$stream.Close()
