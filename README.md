# Digital Heart Rate Estimator Using ECG Signal Processing

**Duration:** Mar 2025 - Apr 2025  
**Tools & Technologies:** Verilog, RTL Design, Digital Signal Processing (DSP), Icarus Verilog, GTKWave

---

## Project Overview

This project implements a **real-time heart rate estimation system** using ECG (Electrocardiogram) signal processing in **Verilog HDL**. The design processes ECG signals to detect R-peaks, calculates RR intervals, and computes the heart rate in BPM (beats per minute). The system is robust against noise and varying input conditions, making it suitable for real-time digital applications.

---

## Features

- **ECG Preprocessing:** Implements a 5-point derivative filter, rectification, and moving-window integration for robust QRS feature extraction.  
- **Adaptive Peak Detection:** Self-adaptive threshold detector ensures accurate R-peak detection under varying signal and noise conditions.  
- **RR Interval Calculation:** Computes RR intervals with configurable averaging to improve accuracy and reduce sensitivity to outliers.  
- **Real-Time BPM Calculation:** Continuously estimates heart rate in beats per minute based on RR intervals.  
- **Simulation & Verification:** Verified using Icarus Verilog and GTKWave with ECG-like signals.

---

## Repository Structure

