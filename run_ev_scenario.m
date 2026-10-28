function result = run_ev_scenario(scenario, workload)
%RUN_EV_SCENARIO Validate configuration, reset callback state and run GPenSIM.
if nargin == 0, scenario = ev_default_scenario(); end
defaults = ev_default_scenario();
fields = fieldnames(defaults);
for k = 1:numel(fields)
    if ~isfield(scenario, fields{k}), scenario.(fields{k}) = defaults.(fields{k}); end
end
validateattributes(scenario.grid_capacity_kW, {'numeric'}, {'scalar','finite','positive'});
validateattributes(scenario.arrival_interval_minutes, {'numeric'}, {'scalar','finite','positive'});
validateattributes(scenario.delta_time_minutes, {'numeric'}, {'scalar','finite','positive'});
counts = [scenario.normal_chargers scenario.medium_chargers scenario.fast_chargers];
assert(numel(counts)==3 && all(ismember(counts,[0 1])) && any(counts), ...
    'This architecture supports 0 or 1 charger per type, with at least one enabled.');
requested = scenario;
if nargin < 2, workload = generate_ev_workload(scenario); end
assert(istable(workload) && all(ismember({'VehicleID','ArrivalTimeMinutes','Type','MaxPowerKW','EnergyRequiredKWh'}, ...
    workload.Properties.VariableNames)), 'Invalid workload table.');
n = height(workload);
assert(isequal(workload.VehicleID,(1:n)'), 'Vehicle IDs must follow FIFO order.');
assert(all(isfinite(workload.ArrivalTimeMinutes) & workload.ArrivalTimeMinutes > 0) ...
    && all(diff(workload.ArrivalTimeMinutes)>0), 'Arrivals must be positive and strictly increasing.');
scenario.vehicle_types = cellstr(workload.Type);
scenario.vehicle_max_power_kW = workload.MaxPowerKW;
scenario.vehicle_energy_kWh = workload.EnergyRequiredKWh;
scenario.arrival_times_minutes = workload.ArrivalTimeMinutes;
% Preserve the verified fixed-interval path when that is the supplied schedule.
scenario.use_arrival_schedule = ~strcmpi(scenario.workload_mode,'deterministic') ...
    || ~isequal(workload.ArrivalTimeMinutes,(1:n)'*scenario.arrival_interval_minutes);
assert(all(ismember(scenario.vehicle_types, {'A','B','C'})), 'Unknown vehicle type.');
assert(all(isfinite(scenario.vehicle_max_power_kW) & scenario.vehicle_max_power_kW>0));
assert(all(isfinite(scenario.vehicle_energy_kWh) & scenario.vehicle_energy_kWh>0));
validateattributes(scenario.battery_enabled, {'logical','numeric'}, {'scalar','binary'});
if ~scenario.battery_enabled
    % A disabled battery has zero capacity, energy and power everywhere.
    scenario.battery_capacity_kWh = 0;
    scenario.battery_initial_energy_kWh = 0;
    scenario.battery_max_discharge_kW = 0;
    scenario.battery_max_charge_kW = 0;
else
    validateattributes(scenario.battery_capacity_kWh, {'numeric'}, {'scalar','finite','positive'});
    validateattributes(scenario.battery_initial_energy_kWh, {'numeric'}, {'scalar','finite','nonnegative'});
    validateattributes(scenario.battery_max_discharge_kW, {'numeric'}, {'scalar','finite','nonnegative'});
    validateattributes(scenario.battery_max_charge_kW, {'numeric'}, {'scalar','finite','positive'});
    assert(scenario.battery_initial_energy_kWh <= scenario.battery_capacity_kWh);
end
% Each vehicle must have at least one grid-only path, guaranteeing progress
% even if the finite battery empties (no recharge until workload finishes).
ratings = [22;50;150];
assert(all(min(scenario.vehicle_max_power_kW(:), min(ratings(logical(counts)))) ...
    <= scenario.grid_capacity_kW), 'Scenario could deadlock after battery exhaustion.');
if n == 0
    result = ev_empty_result(scenario, workload, requested);
    return;
end
if scenario.verbose
    [m, sim, seconds] = ev_simulate_scenario(scenario);
    transcript = '';
else
    transcript = evalc('[m, sim, seconds] = ev_simulate_scenario(scenario);');
end
result.scenario_name = scenario.name;
result.scenario = requested;
result.effective_scenario = scenario;
result.vehicles_completed = height(m.vehicles);
result.last_vehicle_completion_time = m.lastVehicleCompletionTime;
result.simulation_end_time = m.simulationEndTime;
result.mean_wait_minutes = mean(m.vehicles.WaitingTime);
result.max_wait_minutes = max(m.vehicles.WaitingTime);
result.max_queue_length = m.maxQueueLength;
result.grid_capacity_kW = m.grid.capacityKW;
result.peak_grid_load_kW = m.grid.peakLoadKW;
result.average_grid_load_kW = m.grid.averageLoadKW;
result.peak_grid_utilization_percent = m.grid.peakUtilizationPercent;
result.average_grid_utilization_percent = m.grid.averageUtilizationPercent;
result.full_grid_blocks = m.grid.fullBlocks;
result.grid_preference_fallbacks = m.grid.preferenceBlocks;
result.total_grid_wait_minutes = m.grid.totalGridWaitMinutes;
result.mean_grid_wait_minutes = m.grid.meanGridWaitMinutes;
result.battery_enabled = logical(scenario.battery_enabled);
result.battery_capacity_kWh = m.battery.capacityKWh;
result.battery_energy_used_kWh = m.battery.consumedEnergyKWh;
result.battery_energy_recharged_kWh = m.battery.rechargedEnergyKWh;
result.battery_assisted_sessions = m.battery.assistedSessions;
result.peak_battery_discharge_kW = m.battery.peakDischargeKW;
result.minimum_battery_energy_kWh = m.battery.minimumEnergyKWh;
result.battery_recovery_time_minutes = m.battery.recoveryDuration;
result.throughput_vehicles_per_hour = result.vehicles_completed / result.last_vehicle_completion_time * 60;
result.runtime_seconds = seconds;
result.vehicles = m.vehicles;
result.metrics = m;
result.sim = sim;
result.transcript = transcript;
result.random_seed = scenario.random_seed;
result.arrival_horizon_minutes = scenario.arrival_horizon_minutes;
result.generated_vehicle_count = n;
result.number_type_A = sum(strcmp(workload.Type,'A'));
result.number_type_B = sum(strcmp(workload.Type,'B'));
result.number_type_C = sum(strcmp(workload.Type,'C'));
result.mean_generated_energy_kWh = mean(workload.EnergyRequiredKWh);
result.workload = workload;
result.vehicles.ScheduledArrivalMinutes = workload.ArrivalTimeMinutes;
result.metrics.vehicles = result.vehicles;
end
