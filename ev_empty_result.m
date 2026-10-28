function r = ev_empty_result(s, workload, requested)
% Zero arrivals is a legitimate Poisson outcome. No EV simulation is needed.
fields = {'vehicles_completed','last_vehicle_completion_time','mean_wait_minutes', ...
    'max_wait_minutes','max_queue_length','peak_grid_load_kW','average_grid_load_kW', ...
    'peak_grid_utilization_percent','average_grid_utilization_percent','full_grid_blocks', ...
    'grid_preference_fallbacks','total_grid_wait_minutes','mean_grid_wait_minutes', ...
    'battery_energy_used_kWh','battery_assisted_sessions','peak_battery_discharge_kW', ...
    'throughput_vehicles_per_hour','runtime_seconds','generated_vehicle_count', ...
    'number_type_A','number_type_B','number_type_C'};
for k=1:numel(fields), r.(fields{k})=0; end
r.scenario_name = s.name; r.scenario = requested; r.effective_scenario = s;
r.grid_capacity_kW = s.grid_capacity_kW;
r.battery_enabled = logical(s.battery_enabled);
r.battery_capacity_kWh = s.battery_capacity_kWh;
r.minimum_battery_energy_kWh = s.battery_initial_energy_kWh;
r.battery_energy_recharged_kWh = s.battery_capacity_kWh-s.battery_initial_energy_kWh;
r.battery_recovery_time_minutes = 0;
if r.battery_energy_recharged_kWh > 0
    duration = r.battery_energy_recharged_kWh/min(s.battery_max_charge_kW,s.grid_capacity_kW)*60;
    r.battery_recovery_time_minutes = ceil(duration/s.delta_time_minutes)*s.delta_time_minutes;
end
r.simulation_end_time = r.battery_recovery_time_minutes;
r.random_seed = s.random_seed; r.arrival_horizon_minutes = s.arrival_horizon_minutes;
r.mean_generated_energy_kWh = NaN; % No observations to average.
r.workload = workload; r.vehicles = workload; r.sim = [];
r.metrics = struct('currentGridLoadKW',0,'lastVehicleCompletionTime',0, ...
    'simulationEndTime',r.simulation_end_time);
r.metrics.battery = struct('currentEnergyKWh',s.battery_capacity_kWh, ...
    'currentChargeKW',0,'currentDischargeKW',0);
r.transcript = 'Empty workload: no EV firings; only idle battery recovery, if required.';
end
