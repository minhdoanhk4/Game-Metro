Add-Type -AssemblyName System.Speech
$synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
$synth.SetOutputToWaveFile("c:\Users\msi2k\Documents\FPTU_MATERIAL\PRU\Metro Train\Assets\station_welcome.wav")
$synth.Speak("Welcome to the metro station. The train has arrived. Please mind the gap between the train and the platform.")
$synth.Dispose()
