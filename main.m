% ASEN 3200 Lab 1 Code, Group 9
% Jacob Killelea
clear; clc; close all;

filenames = dir('../Group Data Save Here/AM*'); % AM data
% filenames = dir('../Group Data Save Here/PM*'); % AM data

slope_bias = 999.9*ones(length(filenames), 2); % data matrix, placeholder value of 999.9

for i = 1:length(filenames)
  datafile = filenames(i);
  fname    = strcat(datafile.folder, '/', datafile.name);
  
  if contains(fname, 'RWHEEL') % skip reaction wheel tests
    continue
  end

  % load data
  try
    % Time (s)  Gyro Output [rad/s] Input Rate [rad/s]
    % Isn't gyro output in [degrees/s] ?
    data  = load(fname);
    time  = data(:, 1); % seconds
    gyro  = data(:, 2); % reaction gyro movement (deg/s)
    omega = data(:, 3); % base encoder, rotational velocity (rad/s)
  catch exception
    fprintf(2, '[ERROR]: %s - %s\n', datafile.name, exception.message);
    % warning('%s - %s\n', datafile.name, exception.message);
    continue
  end

  % fit a line to the slope
  p = polyfit(omega, gyro, 1); % [slope, offset]
  slope_bias(i, :) = p; % save slope and offset

  % figure; hold on; grid on;
  % scatter(omega, gyro, '.');
  % f = @(x) p(1)*x + p(2); % line fit function
  % plot(omega, f(omega), 'linewidth', 2);
  % title(escape(datafile.name));
  % xlabel('Base movement \omega (rad/s)');
  % ylabel('gyro movement (deg/sec)');
  % print(['img/', datafile.name, '-img'], '-dpng')
  % close
end

% remove unused rows
slope_bias = slope_bias(slope_bias(:, 1) ~= 999.9, :);
fprintf('Slope: %f deg/s per rad/s, sigma %f\n', mean(slope_bias(:, 1)), std(slope_bias(:, 1)));
fprintf('Offest: %f deg/s at 0 rad/s, sigma %f\n', mean(slope_bias(:, 2)), std(slope_bias(:, 2)));
disp(' ');

%  reaction wheel tests
for i = 1:length(filenames)
  datafile = filenames(i);
  fname    = strcat(datafile.folder, '/', datafile.name);

  if ~contains(fname, 'RWHEEL') % only reaction wheel tests
    continue
  end

  try
    % Time [ms]  Commanded Torque [mNm]  Base Speed [rpm]  Actual Current [Amp]
    % Should base be changed to reaction wheel? We held the base stationary for this test...
    data       = load(fname);
    time       = data(:, 1);
    torque     = data(:, 2);
    base_speed = data(:, 3);
    current    = data(:, 4);
  catch exception
    fprintf(2, '[ERROR]: %s - %s\n', datafile.name, exception.message);
    % warning('%s - %s\n', datafile.name, exception.message);
    continue
  end

  % reaction wheel has a torque constant of 33.5 mNm/A
  % actual_torque = current*33.5; % mNm

  % Attempt to only plot where the motor is over 100mA.
  % On some trials the motor doesn't ever reach that
  % so we plot where it's only at 50mA or 25mA or 12.5mA....
  % MATLAB has no mechanism to retry a try/catch block
  % so this is all wrapped in a 'while' loop that we'll break if everything
  % goes right. If there's an error, we loop back to the start.
  figure; hold on; grid on;
  current_min = 100;
  while true
    try
      idx = (1000*current > current_min) & (base_speed < 3500); % 100 mA

      ylim([0, max([1000*current(idx); base_speed(idx)])]);
      plot(time(idx), 1000*current(idx), 'DisplayName', 'current (mA)');
      plot(time(idx), base_speed(idx),   'DisplayName', 'base speed');
      % scatter(time(idx), 1000*current(idx), '.', 'DisplayName', 'current (mA)');
      % scatter(time(idx), base_speed(idx), '.', 'DisplayName', 'base speed');
      legend('show', 'location', 'northwest');
      title(escape(datafile.name));
      print(['img/', datafile.name, '-img'], '-dpng')

      break;
    catch
      current_min = current_min/2;
      fprintf('retrying %s at minimum %.2f mA\n', datafile.name, current_min);
    end
  end
  close;

end
