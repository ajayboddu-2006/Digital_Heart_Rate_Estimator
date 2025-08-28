# Digital Heart Rate Estimator Using ECG Signal Processing

**Duration:** Mar 2025 - Apr 2025  
**Tools & Technologies:** Verilog, RTL Design, Digital Signal Processing (DSP), Icarus Verilog, GTKWave

---

## Project Overview

This project implements a **real-time heart rate estimation system** using ECG signals in Verilog HDL. The system performs preprocessing, adaptive peak detection, RR interval calculation, and BPM computation in a fully digital pipeline. It is designed for robust operation under noisy input conditions and real-time processing constraints.

---

## Module Descriptions

### 1. **HR_estimator (Top-level Module)**

This is the top-level module that integrates all stages of the heart rate estimation pipeline:

- **Inputs:**  
  - `clk`: Clock signal  
  - `rst`: Reset signal  
  - `Xin`: 8-bit signed ECG input signal  

- **Outputs:**  
  - `Yout`: 13-bit processed signal after preprocessing  
  - `peak_detected`: Flag indicating an R-peak has been detected  
  - `avg_interval`: Average RR interval over configurable number of peaks  
  - `bpm`: Estimated heart rate in beats per minute  

**Pipeline Stages:**  
1. **Preprocessing (`heart_rate_pipeline`)**  
2. **Peak Detection (`self_adaptive_threshold`)**  
3. **RR Interval Calculation (`RR_Interval_Calculator`)**  
4. **BPM Calculation (`bpm_calc`)**  

---

### 2. **heart_rate_pipeline**

This module implements the **preprocessing stage** of the ECG signal:

- **Differentiation:**  
  Implements a 5-point derivative filter to emphasize QRS complexes:  

  \[
  y[n] = \frac{-x[n-2] - 2x[n-1] + 2x[n-3] + x[n-4]}{8}
  \]

- **Rectification:**  
  Converts the differentiated signal to absolute values to remove negative excursions.  

- **Integration:**  
  A 16-sample moving window integrator smooths the signal and enhances QRS detection.

- **Output:**  
  - `Yout`: 13-bit preprocessed ECG signal ready for peak detection.

---

### 3. **self_adaptive_threshold**

This module detects **R-peaks** using a self-adaptive threshold:

- Maintains a buffer of the last 256 samples of the preprocessed signal.  
- Tracks the **maximum signal value** dynamically.  
- Sets a **dynamic threshold** as `threshold = (max_value / 2) + 50`.  
- Flags `peak_detected` when the signal exceeds the threshold.  

This approach ensures reliable peak detection under varying signal amplitudes and noise conditions.

---

### 4. **RR_Interval_Calculator**

This module calculates the **average RR interval**:

- Detects **rising edges** of `peak_detected` to identify peaks.  
- Computes intervals between consecutive R-peaks.  
- Maintains a configurable number of intervals (`NUM_PEAKS`) to calculate the average RR interval.  
- Outputs:  
  - `avg_interval`: Average interval in clock cycles  
  - `output_valid`: High when a valid average is computed

This helps smooth out variations and reduces sensitivity to outliers.

---

### 5. **bpm_calc**

This module calculates **beats per minute (BPM)**:

\[
\text{BPM} = \frac{60 \times \text{CLK\_FREQ}}{\text{avg\_interval}}
\]

- Inputs: `rr_cycles` (average RR interval in clock cycles)  
- Output: `bpm` (32-bit heart rate)  

This converts the measured RR interval into a real-world heart rate.

---

## Repository Structure

