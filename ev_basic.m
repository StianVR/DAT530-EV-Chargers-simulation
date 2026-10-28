%EV_BASIC Run the first, simplified EV charging station model.
% Requires GPenSIM on the MATLAB path. Run this script, not ev_basic_pdf.

clear;
clc;
close all;

% Set simulation options explicitly on every run.
% All simulation times are minutes. Use 0.01-minute (0.6-second) steps.
% MAX_LOOP is calculated below from the workload; COMMON_POST stops the
% simulation earlier once every vehicle has finished and the battery is full.
global global_info;
global_info = struct();
global_info.DELTA_TIME = 0.01;
global_info.STOP_SIMULATION = false;
% Vehicle identity follows FIFO allocation order, without colored tokens.
global_info.vehicleTypes = {'A'; 'B'; 'C'; 'A'; 'B'; 'C'};
global_info.vehicleMaxKW = [22; 50; 150; 22; 50; 150];
% Matching rows in these three vectors describe the same FIFO vehicle.
% Vehicle:                1   2   3   4   5   6
global_info.energyKWh = [10; 20; 40; 20; 30; 50];
assert(numel(global_info.energyKWh) == numel(global_info.vehicleTypes) ...
    && numel(global_info.vehicleMaxKW) == numel(global_info.vehicleTypes), ...
    'Each vehicle must have a type, maximum power, and energy request.');
global_info.chargerPowerKW = [22; 50; 150]; % Normal, Medium, Fast
global_info.GRID_CAPACITY = 200; % kW
global_info.currentGridLoad = 0;
global_info.peakGridLoad = 0;
global_info.activePowerKW = zeros(3, 1);
global_info.activeVehicle = zeros(3, 1);
% Log: minute, vehicle, charger index, signed power, load before, load after.
global_info.gridLog = zeros(0, 6);
global_info.BATTERY_CAPACITY_KWH = 100;
global_info.BATTERY_MAX_DISCHARGE_KW = 100;
global_info.initialBatteryEnergyKWh = 100;
global_info.batteryEnergyKWh = 100; % Unreserved energy, debited at start.
global_info.minimumBatteryEnergyKWh = 100;
global_info.currentBatteryDischargeKW = 0;
global_info.peakBatteryDischargeKW = 0;
global_info.activeGridKW = zeros(3, 1);
global_info.activeBatteryKW = zeros(3, 1);
global_info.activeBatteryEnergyKWh = zeros(3, 1);
global_info.vehicleSupply = zeros(6, 3); % Grid kW, battery kW, battery kWh.
global_info.BATTERY_MAX_CHARGE_KW = 50;
global_info.currentBatteryChargeKW = 0;
global_info.rechargedEnergyKWh = 0;
global_info.rechargeStartTime = NaN;
global_info.batteryFullTime = NaN;
global_info.lastVehicleCompletionTime = NaN;
global_info.batteryLog = [0 100 0 0];
% Conservative safety horizon: wait for all arrivals, then charge every
% vehicle sequentially at its slowest possible effective power.
% This exceeds the time needed by our three concurrent charger paths.
slowestKW = min(global_info.vehicleMaxKW, min(global_info.chargerPowerKW));
safetyMinutes = 2 * numel(global_info.vehicleTypes) ...
    + sum(60 .* global_info.energyKWh ./ slowestKW) ...
    + 60 * global_info.BATTERY_CAPACITY_KWH / min(global_info.BATTERY_MAX_CHARGE_KW, global_info.GRID_CAPACITY) + 10;
% Some loops process completions without advancing time; leave extra loops.
global_info.MAX_LOOP = ceil(safetyMinutes / global_info.DELTA_TIME) ...
    + 10 * numel(global_info.vehicleTypes);

% Load the places, transitions, and arcs.
spng = pnstruct('ev_basic_pdf');

% Six vehicles have yet to arrive. The waiting queue starts empty.
% One control token permits one arrival timer to run at a time.
% Places omitted from dyn.m0 start with zero tokens.
dyn.m0 = { ...
    'pToArrive',     6, ...
    'pArrivalReady', 1, ...
    'pDispatch',     1, ... % Serialize allocation, not charging.
    'pAvailNormal', 1, ...
    'pAvailMedium', 1, ...
    'pAvailFast',   1 ...
};

% GPenSIM requires positive firing times. Allocation takes a small amount
% of simulated time (0.001 minutes requested, resolved on 0.01-minute ticks).
% Initial charging times below are
% nominal values. Each completed allocation replaces its charger's duration
% using that vehicle's capability before the charging transition starts.
% The first arrival completes at minute 2, then every 2 minutes.
dyn.ft = { ...
    'tArrival', 2, ...
    'tRecharge', 1, ... % Replaced with exact refill duration after EV service.
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
fprintf('All charging durations match within %.3f minutes (one time step).\n', ...
    metrics.durationToleranceMinutes);
fprintf('Maximum queue length: %d vehicles\n', metrics.maxQueueLength);
fprintf('Mean waiting time (arrival to charging), minutes: %.3f\n', ...
    mean(metrics.vehicles.WaitingTime));
disp(metrics.chargers);
metrics.gridCapacityKW = global_info.GRID_CAPACITY;
metrics.currentGridLoadKW = global_info.currentGridLoad;
metrics.peakGridLoadKW = global_info.peakGridLoad;
metrics.activePowerKW = global_info.activePowerKW;
metrics.vehicles.GridPowerKW = global_info.vehicleSupply(:,1);
metrics.vehicles.BatteryPowerKW = global_info.vehicleSupply(:,2);
metrics.vehicles.BatteryEnergyKWh = global_info.vehicleSupply(:,3);
assert(all(abs(metrics.vehicles.GridPowerKW + metrics.vehicles.BatteryPowerKW ...
    - metrics.vehicles.EffectiveChargingKW) < 1e-9));
% Independently reconstruct grid load from measured session intervals.
powerChanges = sortrows([metrics.vehicles.ChargingStart, metrics.vehicles.GridPowerKW; ...
    metrics.vehicles.CompletionTime, -metrics.vehicles.GridPowerKW], [1 2]);
measuredLoad = cumsum(powerChanges(:, 2));
assert(all(measuredLoad >= -1e-9 & measuredLoad <= metrics.gridCapacityKW + 1e-9), ...
    'Measured session overlap violates the grid limit.');
metrics.gridEvents = array2table(global_info.gridLog, 'VariableNames', ...
    {'TimeMinutes', 'Vehicle', 'ChargerIndex', 'PowerChangeKW', 'LoadBeforeKW', 'LoadAfterKW'});
[metrics.grid, metrics.vehicles] = ev_grid_statistics(metrics.vehicles, ...
    metrics.gridEvents, metrics.gridCapacityKW, global_info.chargerPowerKW, ...
    global_info.initialBatteryEnergyKWh, global_info.BATTERY_MAX_DISCHARGE_KW);
disp(metrics.vehicles);
assert(metrics.currentGridLoadKW == 0 && all(metrics.activePowerKW == 0), ...
    'Grid power was not fully released.');
fprintf('Grid capacity: %.1f kW; peak load: %.1f kW; final load: %.1f kW\n', ...
    metrics.gridCapacityKW, metrics.peakGridLoadKW, metrics.currentGridLoadKW);
fprintf('Peak utilization: %.2f%%; time-weighted average: %.3f kW (%.2f%%)\n', ...
    metrics.grid.peakUtilizationPercent, metrics.grid.averageLoadKW, metrics.grid.averageUtilizationPercent);
fprintf('Grid preference blocks: %d; full blocking episodes: %d\n', ...
    metrics.grid.preferenceBlocks, metrics.grid.fullBlocks);
fprintf('With battery enabled, block/wait metrics mean residual grid+battery supply constraints.\n');
fprintf('Grid-caused wait: total %.3f min; mean %.3f min per vehicle\n', ...
    metrics.grid.totalGridWaitMinutes, metrics.grid.meanGridWaitMinutes);
fprintf('Maximum simultaneous charging sessions: %d\n', ...
    metrics.maxConcurrentCharging);
metrics.battery.capacityKWh = global_info.BATTERY_CAPACITY_KWH;
metrics.battery.initialEnergyKWh = global_info.initialBatteryEnergyKWh;
metrics.battery.currentEnergyKWh = global_info.batteryEnergyKWh;
metrics.battery.minimumEnergyKWh = global_info.minimumBatteryEnergyKWh;
metrics.battery.maxDischargeKW = global_info.BATTERY_MAX_DISCHARGE_KW;
metrics.battery.currentDischargeKW = global_info.currentBatteryDischargeKW;
metrics.battery.peakDischargeKW = global_info.peakBatteryDischargeKW;
metrics.battery.consumedEnergyKWh = sum(metrics.vehicles.BatteryEnergyKWh);
metrics.battery.assistedSessions = sum(metrics.vehicles.BatteryPowerKW > 0);
metrics.battery.history = array2table(global_info.batteryLog, ...
    'VariableNames', {'TimeMinutes','UnreservedEnergyKWh','DischargeKW','ChargeKW'});
assert(metrics.battery.currentDischargeKW == 0);
assert(all(abs(metrics.vehicles.BatteryEnergyKWh - metrics.vehicles.BatteryPowerKW ...
    .* metrics.vehicles.CalculatedChargingMinutes / 60) < 1e-8));
batteryChanges = sortrows([metrics.vehicles.ChargingStart, metrics.vehicles.BatteryPowerKW; ...
    metrics.vehicles.CompletionTime, -metrics.vehicles.BatteryPowerKW], [1 2]);
batteryMeasuredLoad = cumsum(batteryChanges(:,2));
assert(all(batteryMeasuredLoad >= -1e-9 & ...
    batteryMeasuredLoad <= metrics.battery.maxDischargeKW + 1e-9));
assert(abs(metrics.battery.initialEnergyKWh + global_info.rechargedEnergyKWh - metrics.battery.currentEnergyKWh ...
    - metrics.battery.consumedEnergyKWh) < 1e-8);
assert(all(metrics.battery.history.UnreservedEnergyKWh >= 0 & ...
    metrics.battery.history.UnreservedEnergyKWh <= metrics.battery.capacityKWh));
assert(all(metrics.battery.history.ChargeKW >= 0 & ...
    metrics.battery.history.ChargeKW <= global_info.BATTERY_MAX_CHARGE_KW));
fprintf('Battery: %.3f / %.1f kWh remaining; %.3f kWh consumed; %d assisted sessions\n', ...
    metrics.battery.currentEnergyKWh, metrics.battery.capacityKWh, ...
    metrics.battery.consumedEnergyKWh, metrics.battery.assistedSessions);
fprintf('Battery discharge: peak %.3f / %.1f kW; final %.3f kW\n', ...
    metrics.battery.peakDischargeKW, metrics.battery.maxDischargeKW, metrics.battery.currentDischargeKW);
fprintf('Battery initial/minimum energy: %.3f / %.3f kWh\n', ...
    metrics.battery.initialEnergyKWh, metrics.battery.minimumEnergyKWh);
metrics.comparison = table({'Full supply blocks'; 'Direct supply wait (min)'; ...
    'Mean direct supply wait (min)'; 'Final completion (min)'; 'Peak grid load (kW)'}, ...
    [1;22;22/6;111.12;194], [metrics.grid.fullBlocks;metrics.grid.totalGridWaitMinutes; ...
    metrics.grid.meanGridWaitMinutes;max(metrics.vehicles.CompletionTime);metrics.grid.peakLoadKW], ...
    'VariableNames', {'Metric','NoBatteryBaseline','WithBattery'});
disp(metrics.comparison);
metrics.lastVehicleCompletionTime = global_info.lastVehicleCompletionTime;
metrics.battery.maxChargeKW = global_info.BATTERY_MAX_CHARGE_KW;
metrics.battery.currentChargeKW = global_info.currentBatteryChargeKW;
metrics.battery.rechargedEnergyKWh = global_info.rechargedEnergyKWh;
metrics.battery.rechargeStartTime = global_info.rechargeStartTime;
metrics.battery.fullTime = global_info.batteryFullTime;
metrics.simulationEndTime = sim.completion_time;
metrics.battery.recoveryDuration = 0;
metrics.totalGridHistory = table(metrics.grid.history.TimeMinutes, metrics.grid.history.LoadKW, ...
    zeros(height(metrics.grid.history),1), metrics.grid.history.LoadKW, ...
    'VariableNames', {'TimeMinutes','EVGridKW','RechargeGridKW','TotalGridKW'});
if ~isnan(metrics.battery.rechargeStartTime)
    metrics.battery.recoveryDuration = metrics.battery.fullTime - metrics.battery.rechargeStartTime;
    rechargePower = min(metrics.battery.maxChargeKW, metrics.gridCapacityKW);
    expectedRecovery = metrics.battery.rechargedEnergyKWh / rechargePower * 60;
    assert(abs(metrics.battery.recoveryDuration-expectedRecovery) <= sim.delta_T + 1e-8);
    metrics.totalGridHistory = [metrics.totalGridHistory; ...
        table([metrics.battery.rechargeStartTime;metrics.battery.fullTime], [0;0], ...
        [rechargePower;0], [rechargePower;0], ...
        'VariableNames', metrics.totalGridHistory.Properties.VariableNames)];
end
assert(all(metrics.totalGridHistory.TotalGridKW <= metrics.gridCapacityKW + 1e-9));
assert(metrics.battery.currentChargeKW == 0 && metrics.currentGridLoadKW == 0);
assert(abs(metrics.battery.currentEnergyKWh-metrics.battery.capacityKWh) < 1e-8);
assert(abs(metrics.lastVehicleCompletionTime-max(metrics.vehicles.CompletionTime)) < 1e-8);
% Recharge cannot alter any previously recorded EV service interval.
assert(isnan(metrics.battery.rechargeStartTime) || ...
    metrics.battery.rechargeStartTime >= max(metrics.vehicles.CompletionTime));
fprintf('Last EV completion: %.3f min; battery full: %.3f min; simulation end: %.3f min\n', ...
    metrics.lastVehicleCompletionTime, metrics.battery.fullTime, metrics.simulationEndTime);
fprintf('Battery recharged: %.6f kWh; recovery duration: %.3f min\n', ...
    metrics.battery.rechargedEnergyKWh, metrics.battery.recoveryDuration);
fprintf('Grid averages above cover EV service only; totalGridHistory also includes recharge.\n');

% Expected arrivals: approximately 2, 4, 6, 8, 10, and 12 time units.
% Small numerical offsets may occur because simulation uses time steps.
% Expected final marking: pArrivalReady=1, pDispatch=1, each pAvail=1, pDone=6;
% all other places empty. Completion times depend on charger allocation.

