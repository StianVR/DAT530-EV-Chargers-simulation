function test_ev_grid_sensitivity()
% Synthetic summaries and power calculations only; no full simulations.
runs=table();
for seed=1:2
    for grid=[150 200 250]
        for battery=[false true]
            % Deliberately include worsening at 250: never force a hypothesis.
            effect=(grid-200)/25;
            x=10*seed+battery*effect;
            row=struct('Seed',seed,'GridCapacityKW',grid,'BatteryEnabled',battery, ...
                'VehicleCount',10+seed,'MeanWaitMinutes',x,'P95WaitMinutes',2*x, ...
                'MaxQueueLength',seed,'LastEVCompletionMinutes',100+x, ...
                'ThroughputVehiclesPerHour',5-battery*effect,'TotalGridWaitMinutes',x, ...
                'BatteryEnergyUsedKWh',10*double(battery));
            runs=[runs;struct2table(row)]; %#ok<AGROW>
        end
    end
end
e=ev_grid_sensitivity_summary(runs);
assert(height(e.runs)==12 && height(e.paired_differences)==6 && height(e.report)==6);
assert(all(e.paired_differences.MeanWaitMinutes(e.paired_differences.GridCapacityKW==150)==-2));
assert(all(e.paired_differences.MeanWaitMinutes(e.paired_differences.GridCapacityKW==250)==2));
assert(all(e.paired_effects.StdDifference==0));
one=ev_grid_sensitivity_summary(runs(runs.Seed==1,:));
assert(height(one.runs)==6 && all(isnan(one.paired_effects.Approx95CILow)));
reordered=ev_grid_sensitivity_summary(runs([2 1 4 3 6 5 8 7 10 9 12 11],:));
assert(isequal(e.paired_differences,reordered.paired_differences));
bad=runs; bad.VehicleCount(1)=999; rejected=false;
try, ev_grid_sensitivity_summary(bad); catch, rejected=true; end
assert(rejected);
rejected=false;
try, ev_grid_sensitivity_summary(runs(2:end,:)); catch, rejected=true; end
assert(rejected);
[ok,grid,battery,energy]=ev_supply(150,16,72,150,0,100,100);
assert(ok && grid==78 && battery==72 && abs(energy-19.2)<1e-10);
assert(~ev_supply(150,16,72,150,0,100,19));
disp('Grid sensitivity grouping, pairs, single-seed summaries and 150 kW supply checks passed.');
end
