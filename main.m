% ASEN 3200 Lab 1 Code, Group 9
% Jacob Killelea
clear; clc; close all;

filenames = dir('../Group Data Save Here/AM*'); % AM data
% filenames = dir('../Group Data Save Here/PM*'); % AM data

for i = 1:length(filenames)
  datafile = filenames(i);
  fname = strcat(datafile.folder, '/', datafile.name);
  if contains(fname, 'RWHEEL') % skip reaction wheel tests
    continue
  end

  % load data
  data     = load(fname);
  timstamp = data(:, 1); % seconds
  gyro     = data(:, 2); % reaction gyro movement (deg/s)
  omega    = data(:, 3); % base encoder, rotational velocity (rad/s)

  p = polyfit(omega, gyro, 1);
  f = @(x) p(1)*x + p(2);

  figure; hold on; grid on;

  scatter(omega, gyro, '.');
  plot(omega, f(omega), 'linewidth', 2);
  
  title(escape(datafile.name));
  xlabel('Base movement \omega (rad/s)');
  ylabel('gyro movement (deg/sec)');
  print(['img/', datafile.name, '-img'], '-dpng')
  close
end
