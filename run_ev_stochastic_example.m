function result = run_ev_stochastic_example()
s = ev_default_scenario();
s.name = 'Stochastic_Seed42';
s.workload_mode = 'stochastic';
s.random_seed = 42;
s.arrival_horizon_minutes = 480;
s.mean_interarrival_minutes = 10;
w = generate_ev_workload(s);
fprintf('Generated %d vehicles; running the full station model...\n',height(w));
result = run_ev_scenario(s,w);
assert(result.vehicles_completed==height(w));
assert(result.metrics.currentGridLoadKW==0);
assert(result.metrics.battery.currentChargeKW==0 && result.metrics.battery.currentDischargeKW==0);
assert(all(result.vehicles.ArrivalTime >= w.ArrivalTimeMinutes - 1e-8));
fprintf('Seed %d: %d vehicles (A=%d, B=%d, C=%d); mean energy %.3f kWh\n', ...
    result.random_seed,result.generated_vehicle_count,result.number_type_A,result.number_type_B, ...
    result.number_type_C,result.mean_generated_energy_kWh);
fprintf('Wait mean/max: %.3f / %.3f min; max queue: %d\n', ...
    result.mean_wait_minutes,result.max_wait_minutes,result.max_queue_length);
fprintf('Last EV: %.3f min; simulation end: %.3f min; throughput: %.3f vehicles/hour\n', ...
    result.last_vehicle_completion_time,result.simulation_end_time,result.throughput_vehicles_per_hour);
fprintf('Grid peak/average: %.3f / %.3f kW; utilization peak/average: %.2f / %.2f percent\n', ...
    result.peak_grid_load_kW,result.average_grid_load_kW,result.peak_grid_utilization_percent,result.average_grid_utilization_percent);
fprintf('Supply blocks: %d; preference fallbacks: %d; direct wait: %.3f min\n', ...
    result.full_grid_blocks,result.grid_preference_fallbacks,result.total_grid_wait_minutes);
fprintf('Battery used/recharged: %.3f / %.3f kWh; minimum energy: %.3f kWh\n', ...
    result.battery_energy_used_kWh,result.battery_energy_recharged_kWh,result.minimum_battery_energy_kWh);
fprintf('Battery assisted sessions: %d; peak discharge: %.3f kW; recovery: %.3f min\n', ...
    result.battery_assisted_sessions,result.peak_battery_discharge_kW,result.battery_recovery_time_minutes);
end
