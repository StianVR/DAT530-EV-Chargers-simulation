function experiment = ev_monte_carlo_summary(runs)
%EV_MONTE_CARLO_SUMMARY Summarize matched seed rows, Battery minus NoBattery.
seeds = unique(runs.seed,'stable');
n = numel(seeds);
assert(height(runs)==2*n, 'Expected two scenario rows per seed.');
names = {'No_Battery','Baseline_Battery'};
numericFields = runs.Properties.VariableNames;
numericFields = setdiff(numericFields, {'seed','scenario_name'}, 'stable');
important = {'mean_wait_minutes','p95_wait_minutes','max_queue_length', ...
    'throughput_vehicles_per_hour','last_vehicle_completion_time','total_grid_wait_minutes'};
paired = table(seeds,'VariableNames',{'seed'});
percent = paired;
for k=1:numel(important)
    paired.(important{k}) = zeros(n,1);
    percent.(important{k}) = NaN(n,1); % Undefined when baseline is zero.
end
for i=1:n
    a = runs(runs.seed==seeds(i) & strcmp(runs.scenario_name,names{1}),:);
    b = runs(runs.seed==seeds(i) & strcmp(runs.scenario_name,names{2}),:);
    assert(height(a)==1 && height(b)==1, 'Missing/duplicate scenario in pair.');
    assert(a.generated_vehicle_count==b.generated_vehicle_count, 'Mismatched vehicle counts.');
    for k=1:numel(important)
        field = important{k};
        difference = b.(field)-a.(field);
        paired.(field)(i) = difference;
        if a.(field) ~= 0, percent.(field)(i) = 100*difference/a.(field); end
    end
end
rows = cell(0,7);
for scenario=names
    selected = runs(strcmp(runs.scenario_name,scenario{1}),:);
    for metric=numericFields
        x = selected.(metric{1});
        assert(all(isfinite(x)), 'Unexpected NaN/Inf in run metrics.');
        rows(end+1,:) = {scenario{1},metric{1},mean(x),std(x),median(x), ...
            ev_percentile(x,25),ev_percentile(x,75)}; %#ok<AGROW>
    end
end
experiment.scenario_summary = cell2table(rows,'VariableNames', ...
    {'Scenario','Metric','Mean','Std','Median','P25','P75'});
rows = cell(0,8);
counts = zeros(numel(important),1);
for k=1:numel(important)
    field = important{k}; d = paired.(field);
    se = std(d)/sqrt(n);
    low = NaN; high = NaN;
    if n>=2, low=mean(d)-1.96*se; high=mean(d)+1.96*se; end
    rows(end+1,:) = {field,n,mean(d),std(d),median(d),se,low,high}; %#ok<AGROW>
    if strcmp(field,'throughput_vehicles_per_hour'), counts(k)=sum(d>0);
    else, counts(k)=sum(d<0); end
end
experiment.paired_summary = cell2table(rows,'VariableNames', ...
    {'Metric','Pairs','MeanDifference','StdDifference','MedianDifference', ...
    'StandardError','Approx95CILow','Approx95CIHigh'});
experiment.improvements = table(important',counts,repmat(n,numel(important),1), ...
    'VariableNames',{'Metric','ImprovedPairs','TotalPairs'});
experiment.runs = runs;
experiment.paired_differences = paired;
experiment.percent_changes = percent;
experiment.ci_description = 'Approximate normal 95% CI: mean paired difference +/- 1.96*std(d)/sqrt(n).';
experiment.small_sample = n < 30;
end
