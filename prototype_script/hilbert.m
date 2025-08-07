%this is kinda redundant, use vocoder_sim instead.


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

% 🎧 Play your input sound
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
N = 31; % (or increase to 127 for sharper edges)
fs = 44000;

h_hilbert = firpm(N-1, [0.05 0.95], [1 1], 'hilbert');
fixed_pt = round(vpa(h_hilbert).*2^14)


%% Lowpass Filter for Envelope Smoothing
lpFilt = designfilt('lowpassiir', ...
    'FilterOrder', 2, ...
    'HalfPowerFrequency', 50, ...
    'SampleRate', target_fs, ...
    'DesignMethod', 'butter');

%% Extract Envelopes from Each Band
envelopes = cell(n_filters,1);
for i = 1:n_filters
    band_out = filter(filters{i}, speech);
    band_out = band_out(:).'; % force row vector

    % Hilbert-based envelope
    % I = [0, band_out(1:end-1)];
    % Q = filter(h_hilbert, 1, band_out);
    % env = abs(I) + abs(Q);
    % env_smoothed = filtfilt(lpFilt, env);
    I = [zeros(1,(N-1)/2), band_out(1:end-(N-1)/2)]; % Delay in-phase
    Q = filter(h_hilbert, 1, band_out);              % Hilbert transform
    env = abs(I) + abs(Q);                            % Envelope detection
    env_smoothed = filter(lpFilt, env);             % Lowpass smoothing

    envelopes{i} = env_smoothed;
end

%% Carrier Options

[carrier_sample, carrier_fs] = audioread('sample5.wav');

% Resample to match speech
if carrier_fs ~= target_fs
    carrier_sample = resample(carrier_sample, target_fs, carrier_fs);
end

% Force mono
if size(carrier_sample,2) > 1
    carrier_sample = mean(carrier_sample,2);
end

% Normalize
carrier_sample = carrier_sample / max(abs(carrier_sample));

% Trim or pad to match speech length
if length(carrier_sample) > length(speech)
    carrier_sample = carrier_sample(1:length(speech));
else
    carrier_sample = [carrier_sample; zeros(length(speech) - length(carrier_sample),1)];
end


% Normalize carrier
carrier_sample = carrier_sample / max(abs(carrier_sample));

% 🎧 Optional: Listen to carrier alone
sound(carrier_sample, target_fs);


%% Filter the Global Carrier into Bands
carrier_bands = cell(n_filters, 1);
for i = 1:n_filters
    carrier_bands{i} = filter(filters{i}, carrier_sample);
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

