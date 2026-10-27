%EV_BASIC Run the first, simplified EV charging station model.
% Requires GPenSIM on the MATLAB path. Run this script, not ev_basic_pdf.

clear;
clc;
close all;

% Set simulation options explicitly on every run.
% All simulation times are minutes. Use 0.01-minute (0.6-second) steps.
% MAX_LOOP is a safety limit of about 120 minutes; COMMON_POST stops the
% simulation earlier as soon as every vehicle has completed charging.
global global_info;
global_info = struct();
global_info.DELTA_TIME = 0.01;
global_info.MAX_LOOP = 12000;
global_info.STOP_SIMULATION = false;
% Vehicle identity follows FIFO allocation order, without colored tokens.
global_info.vehicleTypes = {'A'; 'B'; 'C'; 'A'; 'B'; 'C'};
global_info.vehicleMaxKW = [22; 50; 150; 22; 50; 150];
global_info.energyKWh = 20 * ones(6, 1);
global_info.chargerPowerKW = [22; 50; 150]; % Normal, Medium, Fast

% Load the places, transitions, and arcs.
spng = pnstruct('ev_basic_pdf');

% Six vehicles have yet to arrive. The waiting queue starts empty.
% One control token permits one arrival timer to run at a time.
% Places omitted from dyn.m0 start with zero tokens.
dyn.m0 = { ...
    'pToArrive',     6, ...
    'pArrivalReady', 1, ...
    'pAvailNormal', 1, ...
    'pAvailMedium', 1, ...
    'pAvailFast',   1 ...
};

% GPenSIM requires positive firing times. Allocation takes a small amount
% of simulated time (0.001 minutes requested, resolved on 0.01-minute ticks).
% Initial charging times below are
% nominal values. Each accepted allocation replaces its charger's duration
% using that vehicle's capability before the charging transition starts.
% The first arrival completes at minute 2, then every 2 minutes.
dyn.ft = { ...
    'tArrival', 2, ...
    'tStartNormal', 0.001, ...
    'tDoneNormal',  20 / 22 * 60, ...
    'tStartMedium', 0.001, ...
    'tDoneMedium',  20 / 50 * 60, ...
    'tStartFast',   0.001, ...
    'tDoneFast',    20 / 150 * 60 ...
};

% Combine the structure and initial conditions, then simulate.
pni = initialdynamics(spng, dyn);
simulationTimer = tic;
sim = gpensim(pni);
simulationSeconds = toc(simulationTimer);
fprintf('Simulation runtime: %.3f seconds\n', simulationSeconds);

prnss(sim);

% The allocation guards enforce this same FIFO vehicle sequence.
metrics = ev_basic_metrics(sim, global_info.vehicleTypes, ...
    global_info.vehicleMaxKW, global_info.energyKWh, global_info.chargerPowerKW);
disp(metrics.vehicles);
fprintf('Maximum queue length: %d vehicles\n', metrics.maxQueueLength);
fprintf('Mean waiting time (arrival to charging), minutes: %.3f\n', ...
    mean(metrics.vehicles.WaitingTime));
disp(metrics.chargers);
fprintf('Maximum simultaneous charging sessions: %d\n', ...
    metrics.maxConcurrentCharging);

% Expected arrivals: approximately 2, 4, 6, 8, 10, and 12 time units.
% Small numerical offsets may occur because simulation uses time steps.
% Expected final marking: pArrivalReady=1, each pAvail place=1, pDone=6;
% all other places empty. Completion times depend on charger allocation.

