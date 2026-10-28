function [grid, vehicles] = ev_grid_statistics(vehicles, events, capacity, ratings, initialEnergy, maxDischarge)
%EV_GRID_STATISTICS Instrumentation only; never changes the simulator.
% Observe time zero through the last completion, including initial idle time.
finish = max(vehicles.CompletionTime);
if nargin < 5
    initialEnergy = 0; maxDischarge = 0;
    vehicles.GridPowerKW = vehicles.EffectiveChargingKW;
    vehicles.BatteryPowerKW = zeros(height(vehicles),1);
    vehicles.BatteryEnergyKWh = zeros(height(vehicles),1);
end
grid.observationMinutes = finish;
grid.capacityKW = capacity;
grid.history = table([0; events.TimeMinutes], [0; events.LoadAfterKW], ...
    'VariableNames', {'TimeMinutes', 'LoadKW'});
% Each recorded load applies until the next event. Simultaneous events
% have zero duration, so they do not distort the time-weighted average.
dt = diff([grid.history.TimeMinutes; finish]);
assert(all(dt >= -1e-9), 'Grid events are not chronological.');
grid.energyKWh = sum(grid.history.LoadKW .* dt) / 60;
grid.averageLoadKW = sum(grid.history.LoadKW .* dt) / finish;
grid.peakLoadKW = max(grid.history.LoadKW);
grid.averageUtilizationPercent = 100 * grid.averageLoadKW / capacity;
grid.peakUtilizationPercent = 100 * grid.peakLoadKW / capacity;
grid.finalLoadKW = grid.history.LoadKW(end);

% Allocation removes the vehicle from pWait before charging starts.
% AllocationStart is taken directly from LOG, not reconstructed by addition.
allocated = vehicles.AllocationStart;
names = {'Normal', 'Medium', 'Fast'};
n = height(vehicles);
charger = zeros(n, 1);
for k = 1:3
    charger(strcmp(vehicles.Charger, names{k})) = k;
end
assert(all(charger > 0), 'Unknown charger in vehicle results.');
boundaries = unique([0; vehicles.ArrivalTime; allocated; ...
    vehicles.ChargingStart; vehicles.CompletionTime]);
wait = zeros(n, 1);
episodes = zeros(0, 3); % vehicle, start minute, end minute
previousHead = 0;
for i = 1:numel(boundaries)-1
    t = boundaries(i); next = boundaries(i+1);
    head = find(vehicles.ArrivalTime <= t & allocated > t, 1);
    blocked = false;
    if ~isempty(head)
        available = true(1, 3);
        busy = allocated <= t & vehicles.CompletionTime > t;
        available(charger(busy)) = false;
        active = vehicles.ChargingStart <= t & vehicles.CompletionTime > t;
        selected = supply_choice(vehicles, head, available, active, t, ratings, capacity, initialEnergy, maxDischarge);
        blocked = any(available) && selected == 0;
    end
    if blocked
        wait(head) = wait(head) + next - t;
        if previousHead ~= head
            episodes(end+1, :) = [head t next]; %#ok<AGROW>
        else
            episodes(end, 3) = next;
        end
        previousHead = head;
    else
        previousHead = 0;
    end
end
grid.fullBlockEpisodes = array2table(episodes, ...
    'VariableNames', {'Vehicle', 'StartMinutes', 'EndMinutes'});
grid.fullBlocks = size(episodes, 1);

% Count a preference block once per actual allocation that uses a fallback
% because a higher-ranked physically available charger exceeds the budget.
fallback = zeros(0, 4); % vehicle, time, blocked charger, chosen charger
for v = 1:n
    t = allocated(v);
    available = true(1, 3);
    busy = allocated < t & vehicles.CompletionTime > t;
    available(charger(busy)) = false;
    active = vehicles.ChargingStart <= t & vehicles.CompletionTime > t;
    active(v) = false;
    preferred = ev_choose_charger(vehicles.VehicleType{v}, available);
    chosen = supply_choice(vehicles, v, available, active, t, ratings, capacity, initialEnergy, maxDischarge);
    assert(chosen == charger(v), 'Reconstructed grid decision differs from allocation.');
    if preferred ~= chosen
        fallback(end+1, :) = [v t preferred chosen]; %#ok<AGROW>
    end
end
grid.preferenceBlockEvents = array2table(fallback, 'VariableNames', ...
    {'Vehicle', 'TimeMinutes', 'BlockedChargerIndex', 'SelectedChargerIndex'});
grid.preferenceBlocks = size(fallback, 1);
vehicles.GridWaitMinutes = wait;
grid.totalGridWaitMinutes = sum(wait);
grid.meanGridWaitMinutes = mean(wait); % All vehicles, including zero waits.
assert(grid.finalLoadKW == 0, 'Final grid load must be zero.');
assert(all(grid.history.LoadKW >= 0 & grid.history.LoadKW <= capacity + 1e-9));
assert(grid.averageLoadKW >= 0 && grid.averageLoadKW <= capacity + 1e-9);
assert(grid.averageUtilizationPercent >= 0 && grid.averageUtilizationPercent <= 100 + 1e-9);
assert(all(wait >= 0 & wait <= vehicles.QueueWait + 1e-8), ...
    'Grid waiting must be a subset of queue waiting.');
end

function selected = supply_choice(v, head, available, active, t, ratings, capacity, initialEnergy, maxDischarge)
load = sum(v.GridPowerKW(active));
discharge = sum(v.BatteryPowerKW(active));
started = v.ChargingStart <= t;
started(head) = false;
energy = max(0, initialEnergy - sum(v.BatteryEnergyKWh(started)));
if ismember('EnergyRequestedKWh', v.Properties.VariableNames)
    request = v.EnergyRequestedKWh(head);
else
    request = 20; % Legacy no-battery statistics fixtures; duration is irrelevant.
end
selected = ev_choose_supply(v.VehicleType{head}, available, v.MaxChargingKW(head), ...
    request, ratings, load, capacity, discharge, maxDischarge, energy);
end

