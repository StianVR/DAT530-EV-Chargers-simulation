function experiment = run_battery_monte_carlo(seeds, outputDirectory)
%RUN_BATTERY_MONTE_CARLO Serial paired experiments; one workload per seed.
if nargin<1, seeds=1:5; end
if nargin<2
    projectRoot = fileparts(fileparts(mfilename('fullpath')));
    outputDirectory=fullfile(projectRoot,'results','battery_monte_carlo');
end
validateattributes(seeds,{'numeric'},{'vector','nonempty','integer','nonnegative','<=',2^32-1});
seeds=seeds(:);
assert(numel(unique(seeds))==numel(seeds),'Seeds must be unique.');
if ~exist(outputDirectory,'dir'), mkdir(outputDirectory); end
base=ev_default_scenario(); base.workload_mode='stochastic'; base.verbose=false;
base.retain_debug=false;
workloads=cell(numel(seeds),1);
runs=table();
for i=1:numel(seeds)
    base.random_seed=seeds(i);
    workload=generate_ev_workload(base); % Exactly once for this seed.
    workloads{i}=workload;
    for battery=[false true]
        scenario=base;
        scenario.battery_enabled=battery;
        if battery, scenario.name='Baseline_Battery'; else, scenario.name='No_Battery'; end
        result=run_ev_scenario(scenario,workload);
        assert(isequal(result.workload,workload),'Simulator changed the paired workload.');
        assert(result.vehicles_completed==height(workload));
        assert(result.metrics.currentGridLoadKW==0);
        assert(result.metrics.battery.currentChargeKW==0 && result.metrics.battery.currentDischargeKW==0);
        waits=zeros(0,1);
        if height(workload)>0, waits=result.vehicles.WaitingTime; end
        row=struct('seed',seeds(i),'scenario_name',string(scenario.name), ...
            'generated_vehicle_count',height(workload), ...
            'mean_wait_minutes',result.mean_wait_minutes, ...
            'max_wait_minutes',result.max_wait_minutes, ...
            'p95_wait_minutes',ev_percentile(waits,95));
        fields={'max_queue_length','last_vehicle_completion_time','throughput_vehicles_per_hour', ...
            'total_grid_wait_minutes','mean_grid_wait_minutes','peak_grid_load_kW', ...
            'average_grid_utilization_percent','full_grid_blocks','battery_energy_used_kWh', ...
            'battery_assisted_sessions','minimum_battery_energy_kWh'};
        for k=1:numel(fields), row.(fields{k})=result.(fields{k}); end
        runs=[runs;struct2table(row)]; %#ok<AGROW>
        clear result;
        % Checkpoint after each scenario; raw GPenSIM logs are not retained.
        save(fullfile(outputDirectory,'battery_monte_carlo_checkpoint.mat'), ...
            'seeds','base','runs','workloads');
        writetable(runs,fullfile(outputDirectory,'battery_monte_carlo_runs.csv'));
    end
    fprintf('Seed %d / %d complete (seed value %d)\n',i,numel(seeds),seeds(i));
end
experiment=ev_monte_carlo_summary(runs);
experiment.seeds=seeds;
experiment.base_scenario=base;
experiment.workloads=workloads;
experiment.workloads_generated=numel(seeds);
experiment.output_directory=outputDirectory;
assert(height(experiment.runs)==2*numel(seeds));
assert(height(experiment.paired_differences)==numel(seeds));
tables={'paired_differences','percent_changes','scenario_summary','paired_summary','improvements'};
for k=1:numel(tables)
    writetable(experiment.(tables{k}),fullfile(outputDirectory,['battery_monte_carlo_' tables{k} '.csv']));
end
save(fullfile(outputDirectory,'battery_monte_carlo_experiment.mat'),'experiment');
fprintf('\nPaired Monte Carlo: Battery - NoBattery (%d pairs)\n',numel(seeds));
if experiment.small_sample
    fprintf('Approximate normal 95%% CIs are exploratory with fewer than 30 pairs.\n');
end
disp(experiment.scenario_summary(ismember(experiment.scenario_summary.Metric, ...
    {'mean_wait_minutes','p95_wait_minutes','throughput_vehicles_per_hour', ...
    'total_grid_wait_minutes','last_vehicle_completion_time','battery_energy_used_kWh','battery_assisted_sessions'}),:));
disp(experiment.paired_summary);
for k=1:height(experiment.improvements)
    fprintf('Battery improved %s in %d / %d runs\n',experiment.improvements.Metric{k}, ...
        experiment.improvements.ImprovedPairs(k),experiment.improvements.TotalPairs(k));
end
end
