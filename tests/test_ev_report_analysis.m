function test_ev_report_analysis()
% Saved-file and synthetic aggregation tests only; never simulate.
root=fileparts(fileparts(mfilename('fullpath')));
paths={fullfile(root,'results','battery_monte_carlo','battery_monte_carlo_runs.csv'), ...
    fullfile(root,'results','grid_sensitivity_1','grid_sensitivity_runs.csv'), ...
    fullfile(root,'results','demand_sensitivity_1','demand_sensitivity_runs.csv')};
families={'battery','grid','demand'};
for k=1:3
    if ~isfile(paths{k}), continue; end
    raw=readtable(paths{k},'TextType','string');
    s=ev_report_summary(raw,families{k});
    if k==1
        off=raw.mean_wait_minutes(strcmp(raw.scenario_name,'No_Battery'));
        assert(abs(s.MeanWait(1)-mean(off))<1e-12);
        assert(abs(s.StdMeanWait(1)-std(off))<1e-12);
        assert(all(s.Seeds==numel(unique(raw.seed))));
    elseif k==2
        assert(isequal(s.GridCapacityKW,[150;150;200;200;250;250]));
        assert(all(s.Seeds==numel(unique(raw.Seed))));
    else
        assert(isequal(s.MeanInterarrivalMinutes,[15;15;10;10;7.5;7.5]));
        assert(isequal(s.DemandLevel,["Low";"Low";"Baseline";"Baseline";"High";"High"]));
        assert(all(s.Seeds==numel(unique(raw.Seed))));
    end
    shuffled=ev_report_summary(raw(end:-1:1,:),families{k});
    assert(isequaln(s,shuffled),'Summary depends on row ordering.');
    rejected=false;
    try, ev_report_summary(raw(2:end,:),families{k}); catch, rejected=true; end
    assert(rejected,'Incomplete experiment accepted.');
    rejected=false;
    bad=raw; bad(:,1)=[];
    try, ev_report_summary(bad,families{k}); catch, rejected=true; end
    assert(rejected,'Missing required columns accepted.');
end
disp('Report schema, pairing, ordering, group counts and saved-value checks passed.');
end
