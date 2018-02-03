% ASEN 3200 Lab 1 Code, Group 9
% Jacob Killelea
clear; clc; close all;

filenames = dir('./data/AM*'); % our data

slope_bias_spread   = 999.9*ones(length(filenames), 3); % data matrix, placeholder value of 999.9
moments_of_intertia = 999.9*ones(length(filenames), 1); % data matrix, placeholder value of 999.9

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
    continue
  end

  % fit a line to the slope
  p = polyfit(omega, gyro, 1); % [slope, offset]
  slope_bias_spread(i, 1:2) = p; % save slope and offset

  figure; hold on; grid on;
  scatter(omega, gyro, '.');

  f = @(x) p(1)*x + p(2); % line fit function
  plot(omega, f(omega), 'linewidth', 2);

  slope = p(1);
  theta = atan(slope);

  low_idx  = gyro < f(omega);
  high_idx = gyro > f(omega);

  tmp = sortrows([omega(high_idx), gyro(high_idx)]);
  high_omega = tmp(:, 1);
  high_gyro  = tmp(:, 2);
  p = polyfit(high_omega, high_gyro, 2);
  h = @(x) p(1).*(x.^2) + p(2).*x + p(3);

  tmp = sortrows([omega(low_idx), gyro(low_idx)]);
  low_omega = tmp(:, 1);
  low_gyro  = tmp(:, 2);
  p = polyfit(low_omega, low_gyro, 2);
  l = @(x) p(1).*(x.^2) + p(2).*x + p(3);

  diff_high = abs(h(0) - f(0));
  diff_low  = abs(l(0) - f(0));
  delta_h   = diff_high*cos(theta);
  delta_l   = diff_low*cos(theta);
  spread    = delta_h + delta_l;
  slope_bias_spread(i, 3) = spread;

  title(escape(datafile.name));
  xlabel('Base movement \omega (rad/s)');
  ylabel('gyro movement (deg/sec)');
  print(['img/', datafile.name, '-img'], '-dpng')
  close
end

% remove unused rows
slope_bias_spread = slope_bias_spread(slope_bias_spread(:, 1) ~= 999.9, :);
fprintf('Slope: %f deg/s per rad/s, sigma %f\n',   mean(slope_bias_spread(:, 1)), std(slope_bias_spread(:, 1)));
fprintf('Offest: %f deg/s at 0 rad/s, sigma %f\n', mean(slope_bias_spread(:, 2)), std(slope_bias_spread(:, 2)));
fprintf('Spread: %f deg/s at 0 rad/s, sigma %f\n', mean(slope_bias_spread(:, 3)), std(slope_bias_spread(:, 3)));
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
    rwheel_speed = rpm2rads(data(:, 3)); % radians per second
    current    = data(:, 4);
  catch exception
    fprintf(2, '[ERROR]: %s - %s\n', datafile.name, exception.message);
    continue
  end

  % reaction wheel has a torque constant of 33.5 mNm/A
  actual_torque = current*33.5/1000; % Nm

  % Attempt to only plot where the motor is over 100mA.
  % On some trials the motor doesn't ever reach that
  % so we plot where it's only at 50mA or 25mA or 12.5mA....
  % MATLAB has no mechanism to retry a try/catch block
  % so this is all wrapped in a 'while' loop that we'll break if everything
  % goes right. If there's an error, we loop back to the start.
  figure; hold on; grid on;
  current_min = 200;
  while true
    try
      idx = (1000*current > current_min) & (rwheel_speed < rpm2rads(3500)); % 100 mA, motor not over 3500 RPM

      ylim([0, max([1000*current(idx); rwheel_speed(idx)])]);
      scatter(time(idx), 1000*current(idx), '.', 'DisplayName', 'current (mA)');
      % scatter(time(idx), actual_torque(idx), '.', 'DisplayName', 'torque (Nm)');
      scatter(time(idx), rwheel_speed(idx), '.', 'DisplayName', 'reaction wheel speed (rad/s)');

      % linear fit
      p = polyfit(time(idx), rwheel_speed(idx), 1);
      f = @(x) p(1)*x + p(2);
      plot(time(idx), f(time(idx)), 'DisplayName', 'fit line')

      torque = mean(actual_torque(idx));
      alpha  = p(1);
      I      = torque/alpha;

      break;
    catch
      current_min = current_min/2;
      fprintf('retrying %s at minimum %.2f mA\n', datafile.name, current_min);
    end
  end

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
