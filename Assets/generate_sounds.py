import wave
import struct
import math
import random
import os

assets_dir = r"c:\Users\msi2k\Documents\FPTU_MATERIAL\PRU\Metro Train\Assets"

def save_wav(filename, samples, sample_rate=44100):
    filepath = os.path.join(assets_dir, filename)
    with wave.open(filepath, 'w') as wav_file:
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(sample_rate)
        # Convert float samples (-1.0 to 1.0) to 16-bit PCM
        for s in samples:
            val = int(max(-1.0, min(1.0, s)) * 32767)
            wav_file.writeframes(struct.pack('<h', val))
    print(f"Generated {filename}")

def generate_horn():
    # Còi tàu: Hai tần số hoà âm 311 Hz (D#4) và 370 Hz (F#4)
    sample_rate = 44100
    duration = 2.0
    samples = []
    for i in range(int(sample_rate * duration)):
        t = i / sample_rate
        # Envelope (Fade in / Fade out nhanh)
        env = min(1.0, t * 10) * min(1.0, (duration - t) * 10)
        # Sóng vuông cho tiếng còi (horn)
        v1 = 0.5 if math.sin(2 * math.pi * 311.13 * t) > 0 else -0.5
        v2 = 0.5 if math.sin(2 * math.pi * 370.0 * t) > 0 else -0.5
        samples.append((v1 + v2) * 0.3 * env)
    save_wav("train_horn.wav", samples)

def generate_doors():
    # Tiếng tít tít tít khi đóng/mở cửa
    sample_rate = 44100
    duration = 2.0
    samples = []
    for i in range(int(sample_rate * duration)):
        t = i / sample_rate
        # 3 tiếng tít
        beep = 1.0 if (t % 0.5) < 0.2 else 0.0
        v = math.sin(2 * math.pi * 1000 * t) * beep * 0.3
        samples.append(v)
    save_wav("train_doors.wav", samples)

def generate_running():
    # Tiếng ầm ầm chạy trên ray (White noise with lowpass filter + rhythmic clack)
    sample_rate = 44100
    duration = 4.0
    samples = []
    val = 0
    for i in range(int(sample_rate * duration)):
        # Lowpass filter on noise (rumble)
        val = 0.95 * val + 0.05 * random.uniform(-1, 1)
        # Tiếng xóc "khục khục" mỗi chu kỳ
        t = i / sample_rate
        clack = 0.0
        if (t % 0.5) < 0.05:
            clack = random.uniform(-0.5, 0.5) * math.exp(-(t % 0.5)*100)
        samples.append(val * 0.5 + clack * 0.3)
    save_wav("train_running.wav", samples)

def generate_bg():
    # Tiếng ồn ào hành khách (Pink-ish noise mô phỏng tiếng đám đông mờ)
    sample_rate = 44100
    duration = 5.0
    samples = []
    val = 0
    for i in range(int(sample_rate * duration)):
        val = 0.99 * val + 0.01 * random.uniform(-1, 1)
        samples.append(val * 1.2)
    save_wav("station_bg.wav", samples)

def generate_click():
    # Tiếng click nhẹ: sóng hình sin 800Hz tắt dần cực nhanh (0.05 giây)
    sample_rate = 44100
    duration = 0.05
    samples = []
    for i in range(int(sample_rate * duration)):
        t = i / sample_rate
        # Envelope: exponential decay
        env = math.exp(-t * 80)
        v = math.sin(2 * math.pi * 800 * t) * env * 0.4
        samples.append(v)
    save_wav("click_sound.wav", samples)

if __name__ == "__main__":
    generate_horn()
    generate_doors()
    generate_running()
    generate_bg()
    generate_click()
