function checks = ev_check_demand_baseline(runs, csvPath, tolerance)
% Compare only the unchanged 10-minute, 200 kW cases to stored Monte Carlo.
baselineRuns=runs(runs.MeanInterarrivalMinutes==10,:);
baselineRuns.GridCapacityKW=repmat(200,height(baselineRuns),1);
checks=ev_check_grid_baseline(baselineRuns,csvPath,tolerance);
end
