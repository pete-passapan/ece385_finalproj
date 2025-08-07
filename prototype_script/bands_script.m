%This script simulates taking a carrier (this one is just a square wave),
%taking a snippet, filtering the snippet, and hearing what it sounds like
%repeated (as well as writing to a .coe file).



%% Load and Loop Carrier Snippet (1 ms)

[carrier_sample, carrier_fs] = audioread('sample8.wav');

% Convert to mono
if size(carrier_sample, 2) > 1
    carrier_sample = mean(carrier_sample, 2);
end

% Resample if needed
if carrier_fs ~= target_fs
    carrier_sample = resample(carrier_sample, target_fs, carrier_fs);
end

% Extract a 1 ms snippet
snippet_length = round(target_fs * 0.09173); % 1 ms at target_fs
if length(carrier_sample) < snippet_length
    error('Carrier file too short for 1 ms snippet.');
end
carrier_snippet = carrier_sample(10000:(10000+snippet_length-1));

% Repeat to match the length of the speech
num_repeats = ceil(length(speech) / snippet_length);
carrier_looped = repmat(carrier_snippet, num_repeats, 1);
carrier_looped = carrier_looped(1:length(speech));  % Trim to match speech length

% Normalize
carrier_sample = carrier_looped / max(abs(carrier_looped));


% Listen to carrier alone
sound(carrier_sample, target_fs);




%% Filter the Global Carrier into Bands
carrier_bands = cell(n_filters, 1);
for i = 1:n_filters
    carrier_bands{i} = filter(filters{i}, carrier_snippet);
end

% Define output directory
output_dir = 'coe_files/';
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

% Normalize and filter the snippet into bands
snippet_len = length(carrier_snippet);
n_filters = length(filters);

carrier_bands = zeros(snippet_len, n_filters);

for i = 1:n_filters
    filtered = filter(filters{i}, carrier_snippet);
    fixed = int16(round(filtered * 32767));     % Q1.15
    carrier_bands(:, i) = fixed;

    % Write each band to a .coe file
    fname = fullfile(output_dir, sprintf('carrier_band_%02d.coe', i));
    fid = fopen(fname, 'w');

    fprintf(fid, 'memory_initialization_radix=16;\n');
    fprintf(fid, 'memory_initialization_vector=\n');

    for j = 1:snippet_len
        val = fixed(j);
        hex_val = dec2hex(typecast(val, 'uint16'), 4);
        fprintf(fid, '%s', hex_val);
        if j < snippet_len
            fprintf(fid, ',\n');
        else
            fprintf(fid, ';\n');
        end
    end

    fclose(fid);
    fprintf('Wrote %s (%d samples)\n', fname, snippet_len);
end

%% Listen to each band-filtered carrier snippet
snippet_len = length(carrier_snippet);
n_filters = length(filters);

% Normalize input snippet just in case
carrier_snippet = carrier_snippet / max(abs(carrier_snippet));

% Set number of repeats for audible playback
repeat_duration_sec = 5; % how long to play each band
repeats = ceil(repeat_duration_sec * target_fs / snippet_len);

disp('Press a key to cycle through bands...');
    % Filter the snippet with current bandpass
    i=11;
    filtered = filter(filters{i}, carrier_snippet);

    % Normalize output
    filtered = filtered / max(abs(filtered));

    % Loop the filtered snippet for ~0.5 seconds
    repeated = repmat(filtered(:), repeats, 1);

    % Playback
    fprintf('Playing carrier band %d...\n', i);
    sound(repeated, target_fs);
    pause(repeat_duration_sec + 0.2);  % give it time to play


%%
% Plot time-domain waveforms of each carrier band
n_plots_per_figure = 5;
snippet_len = length(carrier_snippet);
t = (0:snippet_len-1) / target_fs;

figure_count = 0;

for i = 1:n_filters
    % Filter and normalize
    filtered = filter(filters{i}, carrier_snippet);
    filtered = filtered / max(abs(filtered));

    % New figure every 5 bands
    if mod(i-1, n_plots_per_figure) == 0
        figure_count = figure_count + 1;
        figure(figure_count);
        tiledlayout(n_plots_per_figure, 1);
    end

    % Create subplot
    nexttile;
    plot(t * 1000, filtered);  % convert x-axis to milliseconds
    title(sprintf('Carrier Band %d', i));
    xlabel('Time (ms)');
    ylabel('Amplitude');
    ylim([-1.1 1.1]);
    grid on;
end
