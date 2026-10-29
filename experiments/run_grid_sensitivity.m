function experiment = run_grid_sensitivity(seeds, outputDirectory)
%RUN_GRID_SENSITIVITY Serial 150/200/250 kW x battery off/on experiment.
% Runs full simulations. Launch explicitly; default is only one seed.
if nargin<1, seeds=1; end
root=fileparts(fileparts(mfilename('fullpath')));
if nargin<2, outputDirectory=fullfile(root,'results',sprintf('grid_sensitivity_%d',numel(seeds))); end
validateattributes(seeds,{'numeric'},{'vector','nonempty','integer','nonnegative','<=',2^32-1});
seeds=seeds(:); assert(numel(unique(seeds))==numel(seeds),'Seeds must be unique.');
if ~exist(outputDirectory,'dir'), mkdir(outputDirectory); end
base=ev_default_scenario(); base.workload_mode='stochastic'; base.verbose=false; base.retain_debug=false;
levels=[150 200 250]; workloads=cell(numel(seeds),1); runs=table();
for i=1:numel(seeds)
    base.random_seed=seeds(i);
    workload=generate_ev_workload(base); % One generation, six uses.
    workloads{i}=workload;
    for grid=levels
        for battery=[false true]
            scenario=base; scenario.grid_capacity_kW=grid; scenario.battery_enabled=battery;
            if battery, label='ON'; else, label='OFF'; end
            scenario.name=sprintf('Grid_%d_Battery_%s',grid,label);
            r=run_ev_scenario(scenario,workload);
            assert(isequal(r.workload,workload),'Workload changed between configurations.');
            assert(r.vehicles_completed==height(workload));
            assert(r.metrics.currentGridLoadKW==0 && r.metrics.battery.currentChargeKW==0 ...
                && r.metrics.battery.currentDischargeKW==0);
            assert(r.peak_grid_load_kW<=grid+1e-9 && r.peak_battery_discharge_kW<=100+1e-9);
            if height(workload)>0
                assert(all(r.metrics.totalGridHistory.TotalGridKW<=grid+1e-9));
                waits=r.vehicles.WaitingTime;
            else, waits=zeros(0,1); end
            row=struct('Seed',seeds(i),'GridCapacityKW',grid,'BatteryEnabled',battery, ...
                'VehicleCount',height(workload),'MeanWaitMinutes',r.mean_wait_minutes, ...
                'P95WaitMinutes',ev_percentile(waits,95),'MaxWaitMinutes',r.max_wait_minutes, ...
                'MaxQueueLength',r.max_queue_length,'LastEVCompletionMinutes',r.last_vehicle_completion_time, ...
                'ThroughputVehiclesPerHour',r.throughput_vehicles_per_hour, ...
                'TotalGridWaitMinutes',r.total_grid_wait_minutes,'MeanGridWaitMinutes',r.mean_grid_wait_minutes, ...
                'FullGridBlocks',r.full_grid_blocks,'PeakGridLoadKW',r.peak_grid_load_kW, ...
                'AverageGridLoadKW',r.average_grid_load_kW,'AverageGridUtilizationPercent',r.average_grid_utilization_percent, ...
                'BatteryEnergyUsedKWh',r.battery_energy_used_kWh,'BatteryAssistedSessions',r.battery_assisted_sessions, ...
                'PeakBatteryDischargeKW',r.peak_battery_discharge_kW,'MinimumBatteryEnergyKWh',r.minimum_battery_energy_kWh);
            runs=[runs;struct2table(row)]; %#ok<AGROW>
            clear r;
            save(fullfile(outputDirectory,'grid_sensitivity_checkpoint.mat'),'seeds','base','levels','runs','workloads');
            writetable(runs,fullfile(outputDirectory,'grid_sensitivity_runs.csv'));
            fprintf('Seed %d/%d (value %d) - Grid %d - Battery %s complete\n',i,numel(seeds),seeds(i),grid,label);
        end
    end
end
experiment=ev_grid_sensitivity_summary(runs);
experiment.seeds=seeds; experiment.grid_capacities=levels; experiment.base_scenario=base;
experiment.workloads=workloads; experiment.workloads_generated=numel(seeds);
experiment.output_directory=outputDirectory;
% Read-only comparison with the existing 200 kW experiment, when available.
baselinePath=fullfile(root,'results','battery_monte_carlo','battery_monte_carlo_runs.csv');
experiment.baseline_checks=ev_check_grid_baseline(runs,baselinePath,base.delta_time_minutes);
tables={'summary','paired_differences','paired_effects','improvements','report','effect_report','baseline_checks'};
for k=1:numel(tables)
    writetable(experiment.(tables{k}),fullfile(outputDirectory,['grid_sensitivity_' tables{k} '.csv']));
end
save(fullfile(outputDirectory,'grid_sensitivity_experiment.mat'),'experiment');
disp(experiment.report); disp(experiment.effect_report); disp(experiment.improvements);
fprintf('%s\n',experiment.ci_note);
fprintf('200 kW comparison: %d matched stored baseline rows checked.\n',height(experiment.baseline_checks));
end
