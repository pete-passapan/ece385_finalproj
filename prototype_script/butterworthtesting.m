%% Parameters
fs = 44000;  % 44 kHz sample rate
t = 0:1/fs:0.1;  % 100 ms

% Example input signal: AM modulated sine
fc = 1000;  % carrier frequency 1 kHz
fm = 20;    % modulation frequency 20 Hz
x = (1 + 0.5*sin(2*pi*fm*t)) .* cos(2*pi*fc*t); % modulated carrier

%% FIR Hilbert Transformer
N = 63;  % Must be odd
h = firpm(N-1, [0.05 0.95], [1 1], 'hilbert');

% Delay line
x_delay = [0, x(1:end-1)];

% Hilbert transformed signal
x_hilbert = filter(h, 1, x);

%% Envelope Detection (abs + abs)
abs_I = abs(x_delay);
abs_Q = abs(x_hilbert);

sum_abs = abs_I + abs_Q;

%% Design Butterworth Lowpass using designfilt
lpFilt = designfilt('lowpassiir', ...
    'FilterOrder', 4, ...
    'HalfPowerFrequency', 200, ...
    'SampleRate', fs, ...
    'DesignMethod', 'butter');  % butterworth lowpass

% Apply the lowpass
envelope = filtfilt(lpFilt, sum_abs);  % zero-phase filtering for clean plot

%% Plotting
figure;
subplot(3,1,1);
plot(t, x);
title('Input Modulated Signal');
xlabel('Time [s]');
ylabel('Amplitude');

subplot(3,1,2);
plot(t, abs(x_delay));
hold on;
plot(t, abs(x_hilbert));
legend('abs(I)','abs(Q)');
title('Absolute values of I and Q');
xlabel('Time [s]');
ylabel('Amplitude');

subplot(3,1,3);
plot(t, envelope, 'r');
hold on;
plot(t, (1+0.5*sin(2*pi*fm*t)), 'k--'); % ideal envelope for comparison
legend('Detected Envelope','Ideal Envelope');
title('Envelope Detection (Butterworth LPF using designfilt)');
xlabel('Time [s]');
ylabel('Amplitude');
grid on;

%% Export SOS coefficients (for FPGA use later)
lpSOS = lpFilt.Coefficients;
disp('Lowpass Filter SOS Coefficients:');
disp(lpSOS);
