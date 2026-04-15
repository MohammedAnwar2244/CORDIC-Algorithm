% cordic_model.m
% MATLAB reference model for the RTL CORDIC you posted
% - x,y in Q2.30
% - angle in Q5.27 (input)
% - atan table in Q2.30
% - angle_scaled = angle_q5_27 << 3  (to convert Q5.27 -> Q2.30)
% - iterative rotate mode, no 1/K scaling applied (matches your RTL)

clear; clc; close all;

%% Parameters
WIDTH = 32;
FRAC_XY = 30;    % Q2.30 fractional bits
FRAC_ANG_Q5_27 = 27; % Q5.27 fractional bits
N_ITER = 10;     % must match RTL N_ITER

% generate atan table in Q2.30
atan_table_q2_30 = zeros(1, N_ITER, 'int64');
for i = 0:N_ITER-1
    atan_table_q2_30(i+1) = int64(round( atan(2^-i) * 2^FRAC_XY ));
end

% constants in radians (double)
PI = pi;
TWO_PI = 2*pi;
HALF_PI = pi/2;

% constants in Q5.27 and Q2.30 for comparisons (store as int64)
PI_q5_27   = int64(round(PI * 2^FRAC_ANG_Q5_27));
TWO_PI_q5_27 = int64(round(TWO_PI * 2^FRAC_ANG_Q5_27));
HALF_PI_q5_27 = int64(round(HALF_PI * 2^FRAC_ANG_Q5_27));

% for printing
fmt = 'deg=%3d : cos_actual=%10.8f cos_ref=%10.8f err_cos=%8.6e | sin_actual=%10.8f sin_ref=%10.8f err_sin=%8.6e\n';

%% Helper functions (local nested functions)
    function q = float_to_q(val, frac_bits)
        % convert double value to signed fixed-point integer
        q = int64(round(val * 2^frac_bits));
    end

    function f = q_to_float(q, frac_bits)
        % convert signed fixed-point integer to double
        f = double(q) / 2^frac_bits;
    end

    function s = as_signed_shift(v, sh)
        % arithmetic right shift for signed int64 v by sh bits
        if sh == 0
            s = v;
        else
            % MATLAB's bitshift does arithmetic shift for signed integers
            s = bitshift(v, -sh);
        end
    end

%% compute CORDIC gain K (float) for info
K_float = 1;
for i=0:N_ITER-1
    K_float = K_float * sqrt(1 + 2^(-2*i));
end
fprintf('CORDIC gain K (float, %d iter) = %.10f\n\n', N_ITER, K_float);

%% Test vectors (degrees)
test_degs = [0 30 45 60 90 135 180 270 360 15 75 120 300];

% Run tests
results = zeros(length(test_degs), 6); % [deg cos_act cos_ref err_cos sin_act sin_ref err_sin]
row = 1;
for deg = test_degs
    % -------------------------
    % 1) prepare inputs like RTL:
    % load x_start = 1.0 in Q2.30, y_start = 0
    x_start_q = float_to_q(1.0, FRAC_XY);   % Q2.30 integer
    y_start_q = int64(0);
    
    % 2) normalize input angle to [-pi,pi] in floating then convert to Q5.27,
    %    then perform same mapping to [-pi/2, pi/2] with sign_flag as RTL does.
    ang_rad = mod(deg,360) * pi/180; % in [0,2pi)
    if ang_rad > pi
        ang_rad = ang_rad - 2*pi; % now in (-pi, pi]
    end
    % convert to Q5.27
    angle_q5_27 = float_to_q(ang_rad, FRAC_ANG_Q5_27);
    
    % replicate RTL mapping to [-pi/2,pi/2] with sign_flag:
    sign_flag = false;
    % operate in integer Q5.27 to compare with PI etc
    if angle_q5_27 > PI_q5_27
        angle_q5_27 = angle_q5_27 - TWO_PI_q5_27;
    elseif angle_q5_27 < -PI_q5_27
        angle_q5_27 = angle_q5_27 + TWO_PI_q5_27;
    end
    if angle_q5_27 < -HALF_PI_q5_27
        angle_q5_27 = angle_q5_27 + PI_q5_27;
        sign_flag = true;
    elseif angle_q5_27 > HALF_PI_q5_27
        angle_q5_27 = angle_q5_27 - PI_q5_27;
        sign_flag = true;
    end
    
    % angle_scaled = angle_q5_27 << 3  (Q5.27 -> Q2.30)
    angle_scaled_q2_30 = bitshift(angle_q5_27, 3); % int64
    
    % -------------------------
    % 3) iterative CORDIC (integer arithmetic) using same compare: acc_angle < angle_scaled
    x_q = x_start_q;
    y_q = y_start_q;
    acc_angle_q2_30 = int64(0);
    for i = 0:N_ITER-1
        if acc_angle_q2_30 < angle_scaled_q2_30
            % rotate positive
            x_new = x_q - as_signed_shift(y_q, i);
            y_new = y_q + as_signed_shift(x_q, i);
            acc_angle_q2_30 = acc_angle_q2_30 + atan_table_q2_30(i+1);
        else
            % rotate negative
            x_new = x_q + as_signed_shift(y_q, i);
            y_new = y_q - as_signed_shift(x_q, i);
            acc_angle_q2_30 = acc_angle_q2_30 - atan_table_q2_30(i+1);
        end
        x_q = x_new;
        y_q = y_new;
    end
    
    % apply sign_flag as RTL does
    if sign_flag
        x_q = -x_q;
        y_q = -y_q;
    end
    
    % x_q,y_q are Q2.30 scaled by K (no 1/K applied in RTL)
    cos_act = q_to_float(x_q, FRAC_XY); % this is K * cos(theta)
    sin_act = q_to_float(y_q, FRAC_XY); % this is K * sin(theta)
    
    % compute reference cos/sin (floating)
    cos_ref = cos(deg*pi/180);
    sin_ref = sin(deg*pi/180);
    
    % if you want to compare the actual cos (without K) divide by K
    cos_act_unscaled = cos_act / K_float;
    sin_act_unscaled = sin_act / K_float;
    
    err_cos = abs(cos_act_unscaled - cos_ref);
    err_sin = abs(sin_act_unscaled - sin_ref);
    
    % store results: [deg cos_act_unscaled cos_ref err_cos sin_act_unscaled sin_ref err_sin]
    results(row,:) = [deg, cos_act_unscaled, cos_ref, err_cos, sin_act_unscaled, sin_ref, err_sin];
    
    % print line
    fprintf(fmt, deg, cos_act_unscaled, cos_ref, err_cos, sin_act_unscaled, sin_ref, err_sin);
    
    row = row + 1;
end

% Summary
max_err_cos = max(results(:,4));
max_err_sin = max(results(:,7));
fprintf('\nSummary: max error cos = %g, max error sin = %g (after dividing by K)\n', max_err_cos, max_err_sin);

% optional: show table
T = array2table(results, 'VariableNames', ...
    {'deg','cos_act','cos_ref','err_cos','sin_act','sin_ref','err_sin'});
disp(T);

% end of file
