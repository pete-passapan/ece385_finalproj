%this is an optimistic simulatinon of taking a filtered snippet, repeating
%it, and modulating it with teh envelope (can choose between hilbert and
%second order LPF butterworth). the cutoff of the lpf SHOULD be 80-100 hz
%to sound good... but i was rightfully worried about the number of DSPs
%this would take up so i decided to do a lower order LPF and higher cutoff,
%which makes the coefficients less susceptible to roundoff error---when
%using narrower passbands, there's about a 50% quantization error from the
%actual value to q2.14 fixed point, resulting extremely inaccurate
%envelopes in vivado.

%% Load your real WAV file
[raw_speech, raw_fs] = audioread('sample1.wav');

% If stereo, convert to mono
if size(raw_speech,2) == 2
    raw_speech = mean(raw_speech,2);
end

% Target sample rate
target_fs = 44000; % You can change this!

% Resample if needed
if raw_fs ~= target_fs
    disp(['Resampling from ', num2str(raw_fs), ' Hz to ', num2str(target_fs), ' Hz...']);
    speech = resample(raw_speech, target_fs, raw_fs);
else
    speech = raw_speech;
end

speech = speech(:).';   % Force row vector
speech = speech / max(abs(speech)); % Normalize

% Limit to 1 second (or pad if needed)
if length(speech) > target_fs
    speech = speech(1:round(5* target_fs));
else
    speech = [speech, zeros(1, round(1 * target_fs) - length(speech))];
end

t = (0:length(speech)-1) / target_fs;

% disp('Playing original (or resampled) audio...');
% sound(speech, target_fs);
% pause(length(speech)/target_fs + 0.5);

%% Define Mel-like Bandpass Filters
n_filters = 15;
lo = 50;
hi = 8000;
band_edges = logspace(log10(lo), log10(hi), n_filters+1);
band_centers = sqrt(band_edges(1:end-1) .* band_edges(2:end));

filters = cell(n_filters,1);
for i = 1:n_filters
    filters{i} = designfilt('bandpassiir', ...
        'FilterOrder', 4, ...
        'HalfPowerFrequency1', band_edges(i), ...
        'HalfPowerFrequency2', band_edges(i+1), ...
        'SampleRate', target_fs, ...
        'DesignMethod', 'butter');
end

%% FIR Hilbert Transformer for Envelope Detection
N = 63; % Number of taps (odd)
fs = 44000;

% Design Hilbert transformer
h_hilbert = firpm(N-1, [0.05 0.95], [1 1], 'hilbert');

% Convert to Q2.14 and round
fixed_pt = round(h_hilbert * 2^14)

% Convert to 16-bit binary strings (2's complement)
bin_strings = dec2bin(mod(fixed_pt, 2^16), 16);  % handles negatives correctly

% Write each tap on its own line
fid = fopen('hilbert_taps.mem', 'w');
for i = 1:length(fixed_pt)
    fprintf(fid, '%s\n', bin_strings(i,:));
end
fclose(fid);



%% Lowpass Filter for Envelope Smoothing
lpFilt = designfilt('lowpassiir', ...
    'FilterOrder', 4, ...
    'HalfPowerFrequency', 100, ...
    'SampleRate', target_fs, ...
    'DesignMethod', 'butter');

fid = fopen('lpf_coeffs.mem', 'w');

vpa(lpFilt.Coefficients) .* (2^14)
sos = round(vpa(lpFilt.Coefficients) .* (2^14))
fprintf(fid, '%s %s %s %s %s\n', ...
        dec2bin(mod(sos(1,1), 2^16), 16), ...
        dec2bin(mod(sos(1,2), 2^16), 16), ...
        dec2bin(mod(sos(1,3), 2^16), 16), ...
        dec2bin(mod(sos(1,5), 2^16), 16), ...
        dec2bin(mod(sos(1,6), 2^16), 16));

fclose(fid);

%% Extract and Plot Envelopes from Each Band
envelopes = cell(n_filters,1);
use_hilbert = true;

figure_count = 1;
subplot_count = 0;

figure;

for i = 1:n_filters
    band_out = filter(filters{i}, speech);
    band_out = band_out(:).'; % force row vector

    if use_hilbert
        % Hilbert-based envelope
        I = [zeros(1, (N-1)/2), band_out(1:end-(N-1)/2)]; % Delay in-phase
        Q = filter(h_hilbert, 1, band_out);               % Hilbert transform
        env = abs(I) + abs(Q);                            % Envelope magnitude
    else
        % Rectifier-based envelope
        env = abs(band_out);
    end

    env_smoothed = filter(lpFilt, env);  % Envelope smoothing
    envelopes{i} = env_smoothed;

    % Plotting logic
    subplot_count = subplot_count + 1;
    subplot(5, 1, subplot_count);
    plot(env_smoothed);
    title(['Envelope of Band ', num2str(i)]);
    xlabel('Sample Index');
    ylabel('Amplitude');

    % After 5 subplots, open a new figure
    if subplot_count == 5
        figure_count = figure_count + 1;
        figure;
        subplot_count = 0;
    end
end


%% Carrier Snippet Setup

snippet_duration_ms = 91.73;  % Change this to set duration (e.g., 1, 2, 5, 10)
snippet_samples = round((snippet_duration_ms / 1000) * target_fs);

% Load the carrier audio
[carrier_sample, carrier_fs] = audioread('sample8.wav');

% Convert to mono
if size(carrier_sample, 2) > 1
    carrier_sample = mean(carrier_sample, 2);
end

% Resample if needed
if carrier_fs ~= target_fs
    carrier_sample = resample(carrier_sample, target_fs, carrier_fs);
end

% Normalize
carrier_sample = carrier_sample / max(abs(carrier_sample));

% Clip the snippet
if length(carrier_sample) < snippet_samples
    error('Carrier audio is too short for requested snippet duration.');
end
carrier_snippet = carrier_sample(10000:(9999+snippet_samples));

% Listen to snippet (optional)
%sound(repmat(carrier_snippet, 20, 1), target_fs);

%% Filter the snippet into bands and repeat
carrier_bands = cell(n_filters, 1);
repeats = ceil(length(speech) / snippet_samples);

for i = 1:n_filters
    band_filtered = filter(filters{i}, carrier_snippet);
    band_filtered = band_filtered / max(abs(band_filtered));  % Normalize
    looped_band = repmat(band_filtered(:), repeats, 1);
    carrier_bands{i} = looped_band(1:length(speech));  % Trim to match speech
end


%% Multiply Envelopes × Carrier Bands
modulated = zeros(length(t), 1);

for i = 1:n_filters
    env = envelopes{i};        % speech envelope in this band
    carrier_band = carrier_bands{i}; % carrier band

    mod_band = env(:) .* carrier_band(:);
    modulated = modulated + mod_band;
end

% Normalize
vocoded = modulated / max(abs(modulated));

%% Listen
disp('Playing vocoded sound...');
sound(vocoded, fs);
% 
% figure;
% plot(t, vocoded);
% title('Vocoded output (1 global carrier)');
% xlabel('Time [s]');
% ylabel('Amplitude');
% xlim([0 0.5]);
% grid on;

