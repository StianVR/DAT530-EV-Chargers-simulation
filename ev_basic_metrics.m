function metrics = ev_basic_metrics(sim, vehicleTypes, vehicleMaxKW, energyKWh, chargerPowerKW)
%EV_BASIC_METRICS Report timings for the configured FIFO vehicle sequence.
% GPenSIM LOG columns after the place markings are:
% transition, state, previous state, firing-set index, start time, end time.
% Only rows with a nonzero transition number describe completed firings.

Ps = sim.No_of_places;
events = sim.LOG(sim.LOG(:, Ps + 1) > 0, :);
transitionNames = {sim.global_transitions.name};
placeNames = {sim.global_places.name};
arrivalId = find(strcmp(transitionNames, 'tArrival'));
arrivalTime = sort(events(events(:, Ps + 1) == arrivalId, Ps + 6));

% Build one row per charging session:
% [allocation start, charging start, completion, charger number].
sessions = zeros(0, 4);
chargerTypes = {'Normal'; 'Medium'; 'Fast'};
busyTime = zeros(3, 1);
sessionCount = zeros(3, 1);
for charger = 1:3
    % Square brackets join character strings, e.g. 'tStart' + 'Normal'.
    startId = find(strcmp(transitionNames, ['tStart' chargerTypes{charger}]));
    doneId = find(strcmp(transitionNames, ['tDone' chargerTypes{charger}]));
    starts = sortrows(events(events(:, Ps + 1) == startId, :), Ps + 5);
    finishes = sortrows(events(events(:, Ps + 1) == doneId, :), Ps + 5);
    assert(size(starts, 1) == size(finishes, 1), ...
        'Some charging sessions are unfinished. Increase the simulation limit.');
    % Each charger handles one vehicle at a time, so its nth allocation
    % corresponds to its nth charging completion.
    sessions = [sessions; starts(:, Ps + 5), finishes(:, Ps + 5), ...
        finishes(:, Ps + 6), repmat(charger, size(starts, 1), 1)]; %#ok<AGROW>
    busyTime(charger) = sum(finishes(:, Ps + 6) - finishes(:, Ps + 5));
    sessionCount(charger) = size(finishes, 1);
end

% Allocation guards use the next unallocated vehicle in this FIFO sequence.
% Match allocations to arrivals in the same order for reporting.
sessions = sortrows(sessions, 1);
n = numel(arrivalTime);
assert(n == 6 && size(sessions, 1) == n, ...
    'Expected exactly six arrivals and six completed charging sessions.');
queueWait = sessions(:, 1) - arrivalTime;
waitingTime = sessions(:, 2) - arrivalTime;
assert(all(queueWait >= -1e-9), 'A session precedes its assigned arrival.');
metrics.vehicles = table((1:n)', arrivalTime, sessions(:, 2), ...
    waitingTime, queueWait, sessions(:, 3), chargerTypes(sessions(:, 4)), ...
    sessions(:, 3) - sessions(:, 2), ...
    'VariableNames', {'Vehicle', 'ArrivalTime', 'ChargingStart', ...
    'WaitingTime', 'QueueWait', 'CompletionTime', 'Charger', 'ChargingDuration'});
metrics.vehicles.VehicleType = vehicleTypes(:);
metrics.vehicles.MaxChargingKW = vehicleMaxKW(:);
metrics.vehicles.EnergyRequestedKWh = energyKWh(:);
metrics.vehicles.ChargerRatedKW = chargerPowerKW(sessions(:, 4));
[calculatedMinutes, effectiveKW] = ev_charge_minutes(energyKWh(:), ...
    vehicleMaxKW(:), metrics.vehicles.ChargerRatedKW);
metrics.vehicles.EffectiveChargingKW = effectiveKW;
metrics.vehicles.CalculatedChargingMinutes = calculatedMinutes;
% Preserve ChargingDuration as the measured value from the event log.
% A completion can fall on the next simulation tick.
assert(all(abs(metrics.vehicles.ChargingDuration - calculatedMinutes) ...
    <= 2 * sim.delta_T + 1e-8), 'Measured charging duration differs from calculation.');

% Actual pWait tokens exclude vehicles already reserved for allocation.
waitId = find(strcmp(placeNames, 'pWait'));
metrics.maxQueueLength = max(sim.LOG(:, waitId));

% Use time zero through the last vehicle's completion, excluding the idle
% simulation tail left by MAX_LOOP. Also show utilization from first arrival.
lastCompletion = max(sessions(:, 3));
metrics.chargers = table(chargerTypes, chargerPowerKW(:), sessionCount, busyTime, ...
    100 * busyTime / lastCompletion, ...
    100 * busyTime / (lastCompletion - arrivalTime(1)), ...
    'VariableNames', {'Charger', 'RatedPowerKW', 'VehiclesCharged', 'ChargingTime', ...
    'UtilizationFromZeroPct', 'UtilizationFromFirstArrivalPct'});

% Count overlapping charging intervals. Process completions (-1) before
% starts (+1) at the same time, so back-to-back sessions do not overlap.
changes = sortrows([sessions(:, 2), ones(n, 1); ...
    sessions(:, 3), -ones(n, 1)], [1 2]);
metrics.maxConcurrentCharging = max(cumsum(changes(:, 2)));

% Check that all vehicles finished and all three resource tokens returned.
expectedFinal = zeros(1, Ps);
finalNames = {'pArrivalReady', 'pAvailNormal', 'pAvailMedium', 'pAvailFast', 'pDone'};
finalCounts = [1 1 1 1 6];
for k = 1:numel(finalNames)
    expectedFinal(strcmp(placeNames, finalNames{k})) = finalCounts(k);
end
assert(isequal(sim.LOG(end, 1:Ps), expectedFinal), ...
    'Unexpected final marking: check vehicle completion and resource return.');
end
