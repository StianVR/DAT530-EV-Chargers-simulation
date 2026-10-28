%EV_BASIC Quick start: run the verified battery scenario with detailed output.
scenario = ev_default_scenario();
scenario.verbose = true;
result = run_ev_scenario(scenario);
% Keep familiar workspace variables available for inspection.
metrics = result.metrics;
sim = result.sim;
