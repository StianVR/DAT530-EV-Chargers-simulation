function test_ev_workload()
s = ev_default_scenario();
d = generate_ev_workload(s);
assert(isequal(d.ArrivalTimeMinutes,(2:2:12)'));
assert(isequal(d.EnergyRequiredKWh,[10;20;40;20;30;50]));
s.workload_mode = 'stochastic';
state = rng;
w = generate_ev_workload(s);
assert(isequal(state,rng), 'Generator should restore the caller RNG.');
assert(isequal(w,generate_ev_workload(s)));
s.random_seed = 43;
assert(~isequal(w,generate_ev_workload(s)));
assert(all(diff(w.ArrivalTimeMinutes)>0) && all(w.ArrivalTimeMinutes <= 480));
types = {'A','B','C'}; powers = [22 50 150];
for k=1:3
    rows = strcmp(w.Type,types{k});
    assert(all(w.MaxPowerKW(rows)==powers(k)));
    assert(all(w.EnergyRequiredKWh(rows)>=s.energy_ranges_kWh(k,1) ...
        & w.EnergyRequiredKWh(rows)<=s.energy_ranges_kWh(k,2)));
end
s.random_seed=42; s.grid_capacity_kW=100; s.battery_enabled=false;
assert(isequal(w,generate_ev_workload(s)), 'Station settings changed traffic demand.');
s.vehicle_type_probabilities=[0.2 0.4 0.3]; rejected=false;
try, generate_ev_workload(s); catch, rejected=true; end
assert(rejected, 'Invalid probabilities were accepted.');
s = ev_default_scenario(); s.workload_mode='stochastic'; s.arrival_horizon_minutes=0;
empty = generate_ev_workload(s); assert(height(empty)==0);
r = run_ev_scenario(s,empty); assert(r.vehicles_completed==0 && r.simulation_end_time==0);
disp('Workload reproducibility, bounds, station independence and empty-demand checks passed.');
end
