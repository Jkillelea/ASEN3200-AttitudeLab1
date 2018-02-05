% ASEN 3200 Lab 1 Code, Group 9
% Jacob Killelea
clear; clc; close all;

[~, ~, ~] = mkdir('img');
filenames = dir('./data/AM*'); % our data

slope_bias   = 999.9*ones(length(filenames), 2); % data matrix, placeholder value of 999.9
moments_of_intertia = 999.9*ones(length(filenames), 1); % data matrix, placeholder value of 999.9

fprintf('%30s | slope  | bias\n', 'name');
for i = 1:length(filenames)
  datafile = filenames(i);
  fname    = strcat(datafile.folder, '/', datafile.name);

  if contains(fname, 'RWHEEL') % skip reaction wheel tests
    continue
  end

  % Time (s)  Gyro Output [deg/s] Input Rate [rad/s]
  data  = load(fname);
  time  = data(:, 1); % seconds
  gyro  = data(:, 2); % reaction gyro movement (deg/s)
  omega = data(:, 3); % base encoder, rotational velocity (rad/s)

  % fit a line to the slope
  p = polyfit(omega, gyro, 1); % [slope, offset]
  f = @(x) p(1)*x + p(2); % line fit function

  slope_bias(i, 1:2) = p; % save slope and offset
  fprintf('%30s | %.3f | %.3f\n', datafile.name, p(1), p(2));

  figure; hold on; grid on;
  scatter(omega, gyro, '.');
  plot(omega, f(omega), 'linewidth', 2);
  title(escape(datafile.name));
  xlabel('Base movement \omega (rad/s)');
  ylabel('gyro movement (deg/sec)');
  print(['img/', datafile.name, '-img'], '-dpng')
  close
end

% remove unused rows
slope_bias = slope_bias(slope_bias(:, 1) ~= 999.9, :);
mean_slope = mean(slope_bias(:, 1));
mean_bias  = std(slope_bias(:, 2));
fprintf('Mean slope: %f deg/s per rad/s, sigma %f\n', mean(slope_bias(:, 1)), ...
                                                      std(slope_bias(:,  1)));
fprintf('Mean bias: %f deg/s at 0 rad/s, sigma %f\n', mean(slope_bias(:, 2)), ...
                                                      std(slope_bias(:,  2)));
disp(' ');

% plot the angular rate and position of each trial
for i = 1:length(filenames)
  datafile = filenames(i);
  fname    = strcat(datafile.folder, '/', datafile.name);

  if contains(fname, 'RWHEEL') % skip reaction wheel tests
    continue
  end

  % Time (s)  Gyro Output [deg/s] Input Rate [rad/s]
  data = load(fname);
  time = data(:, 1); % seconds
  gyro = data(:, 2); % reaction gyro movement (deg/s)

  % correction equation, base movement as a function of gyro measurements
  omega = @(g) (g - mean_bias)/mean_slope;

  % only look at part where gyro is moving quickly
  idx   = abs(gyro) > 5; % more than 5 rad/s
  time  = time(idx);
  gyro  = gyro(idx);
  omega = omega(gyro); % apply correct factor

  % each theta at a given t is an integral of omega from the beginning of measurement
  % to that time t, so we have to perform a ton of integrals here
  f = fit(time, omega, 'smoothingspline');
  theta = zeros(length(time), 1);
  for i = 2:length(time)
    % quick optimization - only integrate over the new interval and add that to the
    % previous value
    theta(i) = theta(i-1) + integral(@(t) f(t), time(i - 1), time(i), 'ArrayValued', true);
  end

  % make some plots
  figure; hold on; grid on;
  plot(time, omega, 'DisplayName', '\omega (rad/s)');
  plot(time, theta, 'DisplayName', '\theta (rad)')
  xlabel('Time [ms]');
  legend('show');
  print(['img/', datafile.name, '-img-omega-theta'], '-dpng')
  close
end


%  reaction wheel tests
for i = 1:length(filenames)
  datafile = filenames(i);
  fname    = strcat(datafile.folder, '/', datafile.name);

  if ~contains(fname, 'RWHEEL') % only reaction wheel tests
    continue
  end

  % Time [ms]  Commanded Torque [mNm]  Base Speed [rpm]  Actual Current [Amp]
  % Should base be changed to reaction wheel? We held the base stationary for this test...
  data       = load(fname);
  time       = data(:, 1);
  torque     = data(:, 2);
  rwheel_speed = rpm2rads(data(:, 3)); % radians per second
  current    = data(:, 4);

  % reaction wheel has a torque constant of 33.5 mNm/A
  actual_torque = current*33.5/1000; % Nm

  figure; hold on; grid on;
  current_min = 200;

  idx = (1000*current > current_min) & (rwheel_speed < rpm2rads(3500)); % 100 mA, motor not over 3500 RPM

  ylim([0, max([1000*current(idx); rwheel_speed(idx)])]);
  scatter(time(idx), 1000*current(idx), '.', 'DisplayName', 'current (mA)');
  scatter(time(idx), rwheel_speed(idx), '.', 'DisplayName', 'reaction wheel speed (rad/s)');

  % linear fit
  p = polyfit(time(idx), rwheel_speed(idx), 1);
  f = @(x) p(1)*x + p(2);
  % plot(time(idx), f(time(idx)), 'DisplayName', 'fit line')

  torque = mean(actual_torque(idx));
  alpha  = p(1);
  I      = torque/alpha;

  xlabel('Time [ms]');
  title(escape(datafile.name));
  legend('show', 'location', 'southeast');
  print(['img/', datafile.name, '-img'], '-dpng')
  close;

  moments_of_intertia(i) = I;
end

% remove unused entrys
moments_of_intertia = moments_of_intertia(moments_of_intertia(:, 1) ~= 999.9, :);
fprintf('Moment of Inertia: %f kg m^2, sigma %f\n', mean(moments_of_intertia), std(moments_of_intertia));
disp(' ');
