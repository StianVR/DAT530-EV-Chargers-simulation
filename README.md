# EV charging simulation

Open this project folder in MATLAB and run:

```matlab
setup_ev_project
```

This adds the code folders to MATLAB's path for the current session. Keep your
GPenSIM toolbox on the path as before. No simulation starts during setup.

```text
ev_basic.m             Quick-start simulation script (sets up paths itself)
setup_ev_project.m     Path setup; no simulations
config/                Default scenario configuration
src/                   Simulation runner, supply logic and statistics
model/                 Petri-net definition
model/callbacks/       GPenSIM PRE/POST callbacks
experiments/           Scenario comparisons and batch entry points
tests/                 Helper tests
analysis/              Saved-result aggregation and report plotting
docs/                  Usage and experiment documentation
results/               Saved MAT/CSV outputs and batch checkpoints
```

GPenSIM finds callbacks by their exact filenames on MATLAB's path. Those names
are unchanged, and setup includes `model/callbacks`. Results and documentation
are deliberately excluded from the MATLAB path. Run setup again after restarting
MATLAB; no permanent user-path changes are made.

When **you** want to run a simulation:

```matlab
ev_basic
% Or, after setup:
scenario = ev_default_scenario();
result = run_ev_scenario(scenario);

experiment30 = run_battery_monte_carlo(1:30, ...
    fullfile('results', 'battery_monte_carlo_30'));
```

Batch outputs now default to `results/battery_monte_carlo/`, independent of the
current working directory. Existing saved results were moved into `results/`.
For example: `load('results/stochastic_seed42_result.mat')` from the project root.

See [scenario and experiment instructions](docs/SCENARIOS.md).

Helper tests named `test_ev_*` do not run a full GPenSIM simulation.
`compare_ev_scenarios`, `run_ev_stochastic_example`, and
`run_battery_monte_carlo` **do** run full simulations; launch these explicitly
when you are ready.

Sensitivity experiments also run full simulations and must be launched explicitly:

```matlab
experimentGrid = run_grid_sensitivity(1);     % Six simulations
experimentDemand = run_demand_sensitivity(1); % Six simulations
```

Use `1:5` after one-seed validation for 30 runs. Each experiment saves to its
own folder under `results/`; see the scenario documentation for details.

Generate report figures **from existing result files only**:

```matlab
setup_ev_project
analysis = generate_report_figures();
```

This runs no simulations. PNG, PDF, FIG and summary CSV outputs go into
`results/figures/`. See [report plotting instructions](docs/REPORT_FIGURES.md)
for explicit source folders, error-bar definitions and larger experiment data.

Analyze the Petri-net structure without running a simulation:

```matlab
setup_ev_project;
result = analyze_ev_petri_net();
```

Inventories, matrices, invariants and the small deterministic reachability
graph are saved in `results/petri_analysis/`. See
[structural analysis and its limits](docs/PETRI_ANALYSIS.md) for the distinction
between token flow, vehicle completion and external MATLAB guards/state.
