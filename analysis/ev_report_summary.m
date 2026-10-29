function summary = ev_report_summary(runs, family)
%EV_REPORT_SUMMARY Validate saved run rows and aggregate with equal seed weights.
common={'Seed','BatteryEnabled','VehicleCount','MeanWaitMinutes','P95WaitMinutes', ...
    'ThroughputVehiclesPerHour','TotalGridWaitMinutes','MaxQueueLength','BatteryEnergyUsedKWh'};
if strcmp(family,'battery')
    old={'seed','scenario_name','generated_vehicle_count','mean_wait_minutes','p95_wait_minutes', ...
        'throughput_vehicles_per_hour','total_grid_wait_minutes','max_queue_length','battery_energy_used_kWh'};
    require_columns(runs,old);
    state=string(runs.scenario_name);
    assert(all(ismember(state,["No_Battery","Baseline_Battery"])), 'Unexpected battery scenario name.');
    data=runs(:,old); data.Properties.VariableNames=common;
    data.BatteryEnabled=state=="Baseline_Battery";
    levels=0; data.Level=zeros(height(data),1);
elseif strcmp(family,'grid')
    require_columns(runs,[common {'GridCapacityKW'}]);
    data=runs; data.Level=data.GridCapacityKW; levels=[150 200 250];
elseif strcmp(family,'demand')
    require_columns(runs,[common {'MeanInterarrivalMinutes'}]);
    data=runs; data.Level=data.MeanInterarrivalMinutes; levels=[15 10 7.5];
else
    error('Unknown report family: %s',family);
end
assert(height(data)>0,'Result file contains no completed runs.');
if ~islogical(data.BatteryEnabled)
    if isnumeric(data.BatteryEnabled)
        assert(all(ismember(data.BatteryEnabled,[0 1])),'Invalid battery state.');
        data.BatteryEnabled=logical(data.BatteryEnabled);
    else
        b=lower(string(data.BatteryEnabled));
        assert(all(ismember(b,["true","false","1","0"])),'Invalid battery state.');
        data.BatteryEnabled=b=="true" | b=="1";
    end
end
assert(all(ismember(data.Level,levels)),'Unexpected sensitivity level.');
numeric=common([1 3:end]);
assert(all(isfinite(data{:,numeric}),'all') && all(data{:,numeric}>=0,'all'), ...
    'Run metrics must be finite and nonnegative.');
assert(all(mod(data.Seed,1)==0) && all(mod(data.VehicleCount,1)==0));
seeds=unique(data.Seed);
assert(height(data)==numel(seeds)*numel(levels)*2, 'Incomplete experiment: expected every seed/configuration.');
for seed=seeds'
    for level=levels
        pair=data(data.Seed==seed & data.Level==level,:);
        assert(height(pair)==2 && sum(pair.BatteryEnabled)==1, 'Missing or duplicate battery pair.');
        assert(pair.VehicleCount(1)==pair.VehicleCount(2),'Paired workloads have different vehicle counts.');
    end
    if strcmp(family,'grid')
        assert(numel(unique(data.VehicleCount(data.Seed==seed)))==1,'Grid configurations have different vehicle counts.');
    end
end
% Stable seed order also makes floating-point reductions reproducible.
data=sortrows(data,'Seed');
summary=table();
for level=levels
    for battery=[false true]
        x=data(data.Level==level & data.BatteryEnabled==battery,:);
        row=struct('BatteryState',"OFF",'BatteryEnabled',battery,'Seeds',height(x), ...
            'MeanVehicleCount',mean(x.VehicleCount),'MeanWait',mean(x.MeanWaitMinutes), ...
            'StdMeanWait',std(x.MeanWaitMinutes),'P95Wait',mean(x.P95WaitMinutes), ...
            'StdP95Wait',std(x.P95WaitMinutes),'Throughput',mean(x.ThroughputVehiclesPerHour), ...
            'TotalGridWait',mean(x.TotalGridWaitMinutes),'MaxQueue',mean(x.MaxQueueLength), ...
            'MeanBatteryEnergyUsed',mean(x.BatteryEnergyUsedKWh), ...
            'StdBatteryEnergyUsed',std(x.BatteryEnergyUsedKWh));
        if battery, row.BatteryState="ON"; end
        if height(x)==1
            row.StdMeanWait=NaN; row.StdP95Wait=NaN; row.StdBatteryEnergyUsed=NaN;
        end
        if strcmp(family,'grid'), row.GridCapacityKW=level; end
        if strcmp(family,'demand')
            names=["Low","Baseline","High"];
            row.DemandLevel=names(levels==level); row.MeanInterarrivalMinutes=level;
        end
        summary=[summary;struct2table(row)]; %#ok<AGROW>
    end
end
end

function require_columns(t, names)
missing=setdiff(names,t.Properties.VariableNames);
assert(isempty(missing),'Missing required result columns: %s',strjoin(missing,', '));
end
