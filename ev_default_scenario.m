function scenario = ev_default_scenario()
%EV_DEFAULT_SCENARIO Verified deterministic battery baseline.
scenario.name = 'Baseline_Battery';
scenario.grid_capacity_kW = 200;
% One independent path per type: supported counts are currently 0 or 1.
scenario.normal_chargers = 1;
scenario.medium_chargers = 1;
scenario.fast_chargers = 1;
scenario.battery_enabled = true;
scenario.battery_capacity_kWh = 100;
scenario.battery_initial_energy_kWh = 100;
scenario.battery_max_discharge_kW = 100;
scenario.battery_max_charge_kW = 50;
scenario.arrival_interval_minutes = 2;
scenario.delta_time_minutes = 0.01;
scenario.vehicle_types = {'A';'B';'C';'A';'B';'C'};
scenario.vehicle_max_power_kW = [22;50;150;22;50;150];
scenario.vehicle_energy_kWh = [10;20;40;20;30;50];
scenario.verbose = false;
scenario.workload_mode = 'deterministic';
scenario.random_seed = 42;
scenario.arrival_horizon_minutes = 480;
scenario.mean_interarrival_minutes = 10;
scenario.vehicle_type_probabilities = [0.30 0.40 0.30];
scenario.energy_ranges_kWh = [10 25; 15 35; 20 50]; % A, B, C rows
end
