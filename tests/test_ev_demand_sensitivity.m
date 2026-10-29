function test_ev_demand_sensitivity()
% Workload generation and synthetic summaries only: no GPenSIM runs.
levels=[15 10 7.5]; s=ev_default_scenario(); s.workload_mode='stochastic'; s.random_seed=1;
workloads=cell(1,3);
for k=1:3
    s.mean_interarrival_minutes=levels(k);
    workloads{k}=generate_ev_workload(s);
    assert(all(workloads{k}.ArrivalTimeMinutes<=480));
    assert(isequal(workloads{k},generate_ev_workload(s)));
end
assert(~isequal(workloads{1}.ArrivalTimeMinutes,workloads{2}.ArrivalTimeMinutes));
assert(~isequal(workloads{2}.ArrivalTimeMinutes,workloads{3}.ArrivalTimeMinutes));
s.mean_interarrival_minutes=10;
assert(isequal(workloads{2},generate_ev_workload(s))); % Unchanged baseline demand.
runs=table();
for seed=1:2
    for interval=levels
        for battery=[false true]
            effect=interval-10; % Includes worsening, ties, and improvements.
            x=20*seed+battery*effect;
            row=struct('Seed',seed,'MeanInterarrivalMinutes',interval,'BatteryEnabled',battery, ...
                'VehicleCount',round(480/interval)+seed,'MeanWaitMinutes',x,'P95WaitMinutes',2*x, ...
                'MaxQueueLength',seed,'LastEVCompletionMinutes',100+x, ...
                'ThroughputVehiclesPerHour',10-battery*effect,'TotalGridWaitMinutes',x, ...
                'BatteryEnergyUsedKWh',10*double(battery),'BatteryAssistedSessions',2*double(battery));
            runs=[runs;struct2table(row)]; %#ok<AGROW>
        end
    end
end
e=ev_demand_sensitivity_summary(runs);
assert(height(e.runs)==12 && height(e.paired_differences)==6 && height(e.report)==6);
assert(height(e.battery_usage)==3);
assert(all(e.paired_differences.MeanWaitMinutes(e.paired_differences.MeanInterarrivalMinutes==15)==5));
assert(all(e.paired_differences.MeanWaitMinutes(e.paired_differences.MeanInterarrivalMinutes==7.5)==-2.5));
assert(all(e.battery_usage.MeanBatteryEnergyUsed==10));
assert(all(e.battery_usage.MeanBatteryAssistedSessions==2));
one=ev_demand_sensitivity_summary(runs(runs.Seed==1,:));
assert(height(one.runs)==6 && all(isnan(one.paired_effects.Approx95CILow)));
reordered=ev_demand_sensitivity_summary(runs([2 1 4 3 6 5 8 7 10 9 12 11],:));
assert(isequal(e.paired_differences,reordered.paired_differences));
bad=runs; bad.VehicleCount(1)=999; rejected=false;
try, ev_demand_sensitivity_summary(bad); catch, rejected=true; end
assert(rejected,'Must reject counts that differ within a matched pair.');
rejected=false;
try, ev_demand_sensitivity_summary(runs(2:end,:)); catch, rejected=true; end
assert(rejected);
disp('Demand generation, within-level pairing, summaries and battery-usage checks passed.');
end
