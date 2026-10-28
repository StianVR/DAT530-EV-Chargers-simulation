function [comparison, results] = compare_ev_scenarios()
%COMPARE_EV_SCENARIOS Run both verified cases and enforce regression bounds.
scenarios(1) = ev_default_scenario();
scenarios(1).name = 'No_Battery';
scenarios(1).battery_enabled = false;
scenarios(2) = ev_default_scenario();
for k = 1:2
    fprintf('Running %s...\n', scenarios(k).name);
    results(k) = run_ev_scenario(scenarios(k)); %#ok<AGROW>
end
dt = scenarios(1).delta_time_minutes;
assert(abs(results(1).mean_wait_minutes-15.550) <= dt + 1e-8);
assert(abs(results(1).total_grid_wait_minutes-22) <= dt + 1e-8);
assert(abs(results(1).last_vehicle_completion_time-111.12) <= dt + 1e-8);
assert(results(1).full_grid_blocks == 1 && results(1).battery_energy_used_kWh == 0);
assert(abs(results(1).simulation_end_time-results(1).last_vehicle_completion_time) < 1e-8);
assert(abs(results(2).mean_wait_minutes-8.213) <= dt + 1e-8);
assert(results(2).total_grid_wait_minutes == 0);
assert(abs(results(2).last_vehicle_completion_time-165.67) <= dt + 1e-8);
assert(abs(results(2).battery_energy_used_kWh-22*16/60) < 1e-8);
assert(abs(results(2).simulation_end_time-172.72) <= dt + 1e-8);
comparison = table({results.scenario_name}', [results.mean_wait_minutes]', ...
    [results.max_queue_length]', [results.total_grid_wait_minutes]', ...
    [results.full_grid_blocks]', [results.peak_grid_load_kW]', ...
    [results.average_grid_utilization_percent]', [results.battery_energy_used_kWh]', ...
    [results.last_vehicle_completion_time]', [results.throughput_vehicles_per_hour]', ...
    'VariableNames', {'Scenario','MeanWaitMinutes','MaxQueue','GridWaitMinutes', ...
    'FullGridBlocks','PeakGridKW','AverageGridUtilizationPct','BatteryEnergyUsedKWh', ...
    'LastEVCompletionMinutes','ThroughputVehiclesPerHour'});
disp(comparison);
disp('Both scenario regression checks passed.');
end
