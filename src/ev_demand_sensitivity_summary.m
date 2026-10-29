function e = ev_demand_sensitivity_summary(runs)
% Summaries and matched battery effects, kept separate at each demand level.
levels = [15 10 7.5]; seeds = unique(runs.Seed,'stable');
assert(height(runs)==numel(seeds)*6,'Expected six configurations per seed.');
metrics = {'MeanWaitMinutes','P95WaitMinutes','MaxQueueLength', ...
    'LastEVCompletionMinutes','ThroughputVehiclesPerHour','TotalGridWaitMinutes'};
allMetrics = setdiff(runs.Properties.VariableNames, ...
    {'Seed','MeanInterarrivalMinutes','BatteryEnabled'},'stable');
assert(all(isfinite(runs{:,allMetrics}),'all'),'Nonfinite run metric.');
paired=table(); summary=cell(0,9); effects=cell(0,9); improvements=cell(0,4);
report=table(); effectReport=table(); batteryUsage=table();
for seed=seeds'
    for level=levels
        part=runs(runs.Seed==seed & runs.MeanInterarrivalMinutes==level,:);
        assert(height(part)==2 && numel(unique(part.VehicleCount))==1, ...
            'Vehicle counts must match within each demand-level pair.');
    end
end
for interval=levels
    for battery=[false true]
        part=runs(runs.MeanInterarrivalMinutes==interval & runs.BatteryEnabled==battery,:);
        assert(height(part)==numel(seeds) && numel(unique(part.Seed))==numel(seeds), ...
            'Missing or duplicate configuration.');
        for metric=allMetrics
            x=part.(metric{1});
            summary(end+1,:)={interval,battery,metric{1},numel(x),mean(x),std(x),median(x), ...
                ev_percentile(x,25),ev_percentile(x,75)}; %#ok<AGROW>
        end
        report=[report;table(interval,battery,mean(part.VehicleCount),mean(part.MeanWaitMinutes),mean(part.P95WaitMinutes),mean(part.MaxQueueLength), ...
            mean(part.TotalGridWaitMinutes),mean(part.ThroughputVehiclesPerHour),mean(part.BatteryEnergyUsedKWh), ...
            'VariableNames',{'MeanInterarrivalMinutes','BatteryEnabled','Vehicles','MeanWait','P95Wait','MaxQueue','GridWait','Throughput','BatteryUsed'})]; %#ok<AGROW>
    end
    differences=zeros(numel(seeds),numel(metrics));
    for i=1:numel(seeds)
        a=runs(runs.Seed==seeds(i) & runs.MeanInterarrivalMinutes==interval & ~runs.BatteryEnabled,:);
        b=runs(runs.Seed==seeds(i) & runs.MeanInterarrivalMinutes==interval & runs.BatteryEnabled,:);
        differences(i,:)=b{1,metrics}-a{1,metrics};
    end
    block=array2table(differences,'VariableNames',metrics);
    block=addvars(block,seeds,repmat(interval,numel(seeds),1),'Before',1, ...
        'NewVariableNames',{'Seed','MeanInterarrivalMinutes'});
    paired=[paired;block]; %#ok<AGROW>
    for k=1:numel(metrics)
        d=differences(:,k); n=numel(d); se=std(d)/sqrt(n);
        low=NaN; high=NaN;
        if n>=2, low=mean(d)-1.96*se; high=mean(d)+1.96*se; end
        effects(end+1,:)={interval,metrics{k},n,mean(d),std(d),median(d),se,low,high}; %#ok<AGROW>
        if strcmp(metrics{k},'ThroughputVehiclesPerHour'), improved=sum(d>0);
        else, improved=sum(d<0); end
        improvements(end+1,:)={interval,metrics{k},improved,n}; %#ok<AGROW>
    end
    assisted=runs(runs.MeanInterarrivalMinutes==interval & runs.BatteryEnabled,:);
    energy=mean(assisted.BatteryEnergyUsedKWh);
    effectReport=[effectReport;table(interval,mean(differences(:,1)),mean(differences(:,2)), ...
        mean(differences(:,6)),mean(differences(:,5)),energy, 'VariableNames', ...
        {'MeanInterarrivalMinutes','DeltaMeanWait','DeltaP95Wait','DeltaGridWait','DeltaThroughput','BatteryEnergyUsed'})]; %#ok<AGROW>
    batteryUsage=[batteryUsage;table(interval,energy,mean(assisted.BatteryAssistedSessions), ...
        mean(differences(:,1)),mean(differences(:,2)), 'VariableNames', ...
        {'MeanInterarrivalMinutes','MeanBatteryEnergyUsed','MeanBatteryAssistedSessions', ...
        'MeanWaitDifference','MeanP95WaitDifference'})]; %#ok<AGROW>
end
e.runs=runs;
e.summary=cell2table(summary,'VariableNames', ...
    {'MeanInterarrivalMinutes','BatteryEnabled','Metric','Runs','Mean','Std','Median','P25','P75'});
e.paired_differences=paired;
e.paired_effects=cell2table(effects,'VariableNames', ...
    {'MeanInterarrivalMinutes','Metric','Pairs','MeanDifference','StdDifference','MedianDifference', ...
    'StandardError','Approx95CILow','Approx95CIHigh'});
e.improvements=cell2table(improvements,'VariableNames', ...
    {'MeanInterarrivalMinutes','Metric','ImprovedWorkloads','TotalWorkloads'});
e.report=report; e.effect_report=effectReport;
e.battery_usage=batteryUsage;
e.ci_note='Approximate normal 95% CI; exploratory below 30 pairs; undefined (NaN) for one pair.';
end


