%this generates teh filter coefficients for the melfrequency bank and also
%simulates the entire process of converting to q2.14 coefficients, the
%direct form 1 biquads, and the final bitshifting of the accumulator. 

%% Generate filters and write to .mem file
fs = 44000;
order = 4;
shift = 14;

lo = 50;
hi = 8000;
n_filters = 15;
bands = logspace(log10(lo), log10(hi), n_filters + 1);
show_filter_response = false;

filts = [];
fid = fopen('sos_coeffs.mem', 'w');

for i = 1:n_filters
    df = designfilt("bandpassiir", ...
        FilterOrder=order, ...
        HalfPowerFrequency1=bands(i), ...
        HalfPowerFrequency2=bands(i+1), ...
        SampleRate=fs, ...
        DesignMethod="butter");

    filts = [filts, df];
    fprintf('Filter %2d: %.1f Hz – %.1f Hz\n', i, bands(i), bands(i+1));
    sos = round(vpa(df.Coefficients) .* (2^14))

    % Write SOS 1
    fprintf(fid, '%s %s %s %s %s\n', ...
        dec2bin(mod(sos(1,1), 2^16), 16), ...
        dec2bin(mod(sos(1,2), 2^16), 16), ...
        dec2bin(mod(sos(1,3), 2^16), 16), ...
        dec2bin(mod(sos(1,5), 2^16), 16), ...
        dec2bin(mod(sos(1,6), 2^16), 16));

    % Write SOS 2
    fprintf(fid, '%s %s %s %s %s\n', ...
        dec2bin(mod(sos(2,1), 2^16), 16), ...
        dec2bin(mod(sos(2,2), 2^16), 16), ...
        dec2bin(mod(sos(2,3), 2^16), 16), ...
        dec2bin(mod(sos(2,5), 2^16), 16), ...
        dec2bin(mod(sos(2,6), 2^16), 16));
end

fclose(fid);

if show_filter_response
    h = fvtool(filts(1));
    h.FrequencyScale = 'Log';
    for i = 2:n_filters
        addfilter(h, filts(i));
    end
end

%% apply filter 5 to multitone
fs = 44e3;
Ts = 1/fs;
n = 0:999;
t = n * Ts;

% Generate input signal: 50 Hz, 450 Hz, 1000 Hz — zero DC
x = 0.8*sin(2*pi*50*t) + 0.6*sin(2*pi*450*t) + 0.4*sin(2*pi*1000*t);
x = x / max(abs(x));                          % Normalize to ±1
x_int16 = int16(round(x * (2^15 - 1)));       % Scale to signed 16-bit



% Define Q2.14 filter coefficients (already scaled)
sos =[178, 0, -178, 16384, -32401, 16102;
178, 0, -178, 16384, -32493, 16162];

% Prepare storage
N = length(x_int16);
y_int16 = zeros(1, N, 'int16');

% Allocate history variables for each biquad section
x_hist1 = zeros(size(sos, 1), 1, 'int32');  % x[n-1]
x_hist2 = zeros(size(sos, 1), 1, 'int32');  % x[n-2]
y_hist1 = zeros(size(sos, 1), 1, 'int32');  % y[n-1]
y_hist2 = zeros(size(sos, 1), 1, 'int32');  % y[n-2]

% Loop over samples
for i = 1:N
    xn = int32(x_int16(i));  % Promote input to int32
    stage_input = xn;        % Input to first section

    % Process each biquad section in cascade
    for s = 1:size(sos,1)
        % Coefficients in Q2.14
        b0 = int32(sos(s,1));
        b1 = int32(sos(s,2));
        b2 = int32(sos(s,3));
        a0 = int32(sos(s,4));  % Always 16384 (Q2.14 = 1.0)
        a1 = int32(sos(s,5));
        a2 = int32(sos(s,6));

        % Direct Form I difference equation (Q2.14 math)
        acc = ...
            b0 * stage_input + ...
            b1 * x_hist1(s) + ...
            b2 * x_hist2(s) - ...
            a1 * y_hist1(s) - ...
            a2 * y_hist2(s);

        % Scale accumulator back down (>> 14)
        yn = bitshift(acc, -14);

        % Saturate result to int16 range
        % yn = max(min(yn, 32767), -32768);

        % Update history buffers
        x_hist2(s) = x_hist1(s);
        x_hist1(s) = stage_input;
        y_hist2(s) = y_hist1(s);
        y_hist1(s) = yn;

        % Output of this stage becomes input to next stage
        stage_input = yn;
    end

    % Final output after all stages
    y_int16(i) = int16(stage_input);
end

% Plot input vs output
figure('Color', 'w');
subplot(2,1,1);
plot(t, double(x_int16));
title('Input Signal (Signed 16-bit)');
xlabel('Time (s)');
ylabel('Amplitude');

subplot(2,1,2);
plot(t, double(y_int16));
title('Filtered Output (Fixed-Point, DF1, Q2.14)');
xlabel('Time (s)');
ylabel('Amplitude');