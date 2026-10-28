function test_ev_monte_carlo()
assert(ev_percentile([],95)==0);
assert(ev_percentile(7,95)==7);
assert(abs(ev_percentile([0 10],95)-9.5)<1e-12);
assert(ev_percentile([4 1 3 2],25)==1.75);
seed=[1;1;2;2;3;3];
scenario_name=repmat(["No_Battery";"Baseline_Battery"],3,1);
generated_vehicle_count=ones(6,1)*10;
mean_wait_minutes=[10;8;20;16;30;24];
runs=table(seed,scenario_name,generated_vehicle_count,mean_wait_minutes);
for f={'p95_wait_minutes','max_queue_length','last_vehicle_completion_time'}
    runs.(f{1})=mean_wait_minutes;
end
runs.total_grid_wait_minutes=[0;0;2;0;4;0];
runs.throughput_vehicles_per_hour=[2;3;3;4;4;5];
e=ev_monte_carlo_summary(runs);
assert(isequal(e.paired_differences.mean_wait_minutes,[-2;-4;-6]));
assert(all(abs(e.percent_changes.mean_wait_minutes+20)<1e-10));
assert(isnan(e.percent_changes.total_grid_wait_minutes(1)));
row=e.paired_summary(strcmp(e.paired_summary.Metric,'mean_wait_minutes'),:);
assert(row.MeanDifference==-4 && row.StdDifference==2 && row.MedianDifference==-4);
assert(abs(row.Approx95CILow-(-4-1.96*2/sqrt(3)))<1e-12);
assert(abs(row.Approx95CIHigh-(-4+1.96*2/sqrt(3)))<1e-12);
assert(all(e.improvements.ImprovedPairs([1 2 3 4 5])==3));
assert(e.improvements.ImprovedPairs(6)==2);
% Pair alignment must not depend on row ordering.
shuffled=ev_monte_carlo_summary(runs([2 1 4 3 6 5],:));
assert(isequal(e.paired_differences,shuffled.paired_differences));
bad=runs; bad.generated_vehicle_count(2)=11;
rejected=false; try, ev_monte_carlo_summary(bad); catch, rejected=true; end
assert(rejected);
disp('Percentiles, pair alignment, differences, zero denominators, summaries and CI checks passed.');
end
