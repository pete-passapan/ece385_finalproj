%This script takes longer audio and writes to a COE file 


% === CONFIG ===
filename = 'sample3.wav';    % Your input WAV file
output_mem_file = 'wav_data.data';  % Output file (bitvector format)
target_fs = 44000;           % Target sampling rate
max_samples = 44000;         % Trim to 1 second

% === LOAD WAV ===
[x, fs] = audioread(filename);

% Convert stereo to mono
if size(x,2) == 2
    x = mean(x,2);
end

% Resample if needed
if fs ~= target_fs
    disp(['Resampling from ', num2str(fs), ' Hz to ', num2str(target_fs), ' Hz...']);
    x = resample(x, target_fs, fs);
end

% Normalize to [-1, 1] and scale to signed 16-bit
x = x / max(abs(x));                % Normalize
x_int16 = int16(round(x * 32767)); % Convert to signed 16-bit

% Trim/pad to exactly max_samples
if length(x_int16) > max_samples
    x_int16 = x_int16(1:max_samples);
else
    x_int16(end+1:max_samples) = 0;
end

% === WRITE TO .MEM (bitvector format) ===
fid = fopen(output_mem_file, 'w');
for i = 1:max_samples
    % Convert signed int16 to 16-bit 2's complement binary string
    binstr = dec2bin(typecast(x_int16(i), 'uint16'), 16);
    fprintf(fid, '%s\n', binstr);
end
fclose(fid);

disp(['Wrote ', num2str(max_samples), ' samples to ', output_mem_file]);


%% 🎧 Play the *final* audio back
disp('Playing back the final memory audio...');
sound(double(x_int16) / (2^15 - 1), target_fs);
pause(length(x_int16)/target_fs + 0.5);


%% Example input (replace with your own .wav or .mem import)
% [pcm_raw, fs] = audioread('yourfile.wav');
% pcm = round(pcm_raw * 32767);  % Convert to int16 range

% OR load from .mem file
% pcm = load('wav_data.mem');  % if already scaled and signed

% === CONFIG ===
filename = 'sample3.wav';    % Your input WAV file
output_mem_file = 'wav_data.data';  % Output file (bitvector format)
target_fs = 44000;           % Target sampling rate
max_samples = 44000;         % Trim to 1 second

% === LOAD WAV ===
[pcm, fs] = audioread(filename);

% Convert stereo to mono
if size(pcm,2) == 2
    pcm = mean(pcm,2);
end

% Resample if needed
if fs ~= target_fs
    disp(['Resampling from ', num2str(fs), ' Hz to ', num2str(target_fs), ' Hz...']);
    pcm = resample(pcm, target_fs, fs);
end

% Normalize to [-1, 1] and scale to signed 16-bit
pcm = pcm / max(abs(pcm));                % Normalize
pcm = int16(round(pcm * 32767)); % Convert to signed 16-bit

% Trim/pad to exactly max_samples
if length(pcm) > max_samples
    pcm = pcm(1:max_samples);
else
    pcm(end+1:max_samples) = 0;
end

% Trim to desired depth (e.g., 44000 samples)
pcm = pcm(1:min(end, 44000));
pcm = int16(pcm(:));  % ensure column vector

%% Write to COE file
fid = fopen('wav_data.coe', 'w');

fprintf(fid, 'memory_initialization_radix=16;\n');
fprintf(fid, 'memory_initialization_vector=\n');

for i = 1:length(pcm)
    hex_val = dec2hex(typecast(pcm(i), 'uint16'), 4);  % signed -> hex
    if i < length(pcm)
        fprintf(fid, '%s,\n', hex_val);
    else
        fprintf(fid, '%s;\n', hex_val);  % no comma on last entry
    end
end

fclose(fid);
disp('WAV data written to wav_data.coe');
