# Running deterministic EV experiments

From the project root, run `setup_ev_project` to add the code folders to the
MATLAB path. Keep the installed GPenSIM toolbox on the path as before.
Setup does not run any simulation.

```matlab
[comparison, results] = compare_ev_scenarios();
```

This runs `No_Battery` then `Baseline_Battery`, checks their known results
within the 0.01-minute time step, and displays a comparison table.

For one experiment:

```matlab
scenario = ev_default_scenario();
scenario.name = 'Grid_180';
scenario.grid_capacity_kW = 180;
result = run_ev_scenario(scenario);
disp(result.vehicles);
```

Set `scenario.verbose = true` for the event log and detailed summaries.
The familiar `ev_basic` script runs the default scenario with verbose output,
leaving `result`, `metrics`, and `sim` in the workspace.

## Configuration

`ev_default_scenario` supplies the grid limit, battery enable flag, capacity,
initial energy, discharge/charge limits, arrival interval, time step, and
deterministic vehicle metadata. Matching vector rows identify the same FIFO
vehicle. First arrival is after one interval, followed by equal intervals.

Charger counts currently support **0 or 1 per type**. The three paths each
represent one physical charger; larger counts are rejected rather than
incorrectly sharing a timed transition. At least one path must be enabled.
The runner rejects configurations in which a vehicle could have no grid-only
path after battery exhaustion. Recharge power must be positive when enabled.

With `battery_enabled = false`, effective battery capacity, initial energy,
and both power limits are zero. Returned battery amounts, power and recovery
duration are zero; the detailed recharge-start timestamp is NaN because no
recharge occurs. The simulation stops at the last EV completion.

## Data flow and results

`run_ev_scenario` validates and normalizes the configuration, then calls
`ev_simulate_scenario`, which contains the previous working simulation.
`global_info` remains necessary for GPenSIM PRE/POST callbacks; it is reset
for every run. `PN` is GPenSIM's live Petri-net state. Experiments run serially.
No callbacks or physical allocation rules were changed for this refactor.

The result includes named summary fields, `vehicles`, detailed `metrics`,
the GPenSIM `sim` output, and a captured `transcript` in quiet mode.
`scenario` records the requested configuration; `effective_scenario` records
normalization such as zeroing a disabled battery's parameters.

Grid averages and throughput use the EV-service observation window starting
at time zero. Throughput is completed vehicles / last EV completion * 60.
Battery recovery remains separate from EV completion. Full simulation load
history including recharge is in `result.metrics.totalGridHistory`.

## Reproducible stochastic demand

The default `workload_mode` is still `deterministic`. To run the eight-hour
example (one run, no tuning or Monte Carlo repetitions):

```matlab
result = run_ev_stochastic_example();
```

To reuse exactly the same demand across station configurations:

```matlab
s = ev_default_scenario();
s.workload_mode = 'stochastic';
s.random_seed = 42;
s.arrival_horizon_minutes = 480;
s.mean_interarrival_minutes = 10;
workload = generate_ev_workload(s);
withoutBattery = s;
withoutBattery.battery_enabled = false;
r0 = run_ev_scenario(withoutBattery, workload);
r1 = run_ev_scenario(s, workload);
```

The workload table contains `VehicleID`, `ArrivalTimeMinutes`, `Type`,
`MaxPowerKW`, and `EnergyRequiredKWh`. It is returned as `result.workload`.
Station settings never enter the generator. For a supplied table, its actual
contents are authoritative; its `Properties.UserData` retains generator
metadata. Result seed/horizon fields describe the scenario configuration.

The generator seeds MATLAB's Twister RNG, generates the complete demand, then
restores the caller's RNG state. Exponential intervals use `-mean*log(U)`.
Uniform draws select A/B/C using cumulative probabilities, then select energy
within the corresponding row of `energy_ranges_kWh`. No Statistics Toolbox
is required. The arrival count is not fixed. A zero-vehicle outcome is valid;
it returns zero EV metrics (mean generated energy is NaN), and any initial
battery deficit is handled as idle recovery without an EV simulation.

The stochastic arrival transition reads the next pre-generated absolute time
in `tArrival_post`; it never draws random numbers. Its next duration subtracts
the current simulated time, avoiding cumulative rounding drift. GPenSIM still
resolves events on its 0.01-minute time step. Extremely close arrivals are
serialized, so scheduled and measured arrival times may differ. Both are
stored in the vehicle results. No scheduled arrival exceeds the horizon,
but charging, waiting and battery recovery may continue beyond it.

Deterministic equally spaced demand retains the previous fixed-duration
arrival path, preserving the verified regression results. Guard/selection
logic, charging, grid and battery behavior remain the same in both modes.

Tests: `test_ev_workload` checks demand generation independently;
`compare_ev_scenarios` retains deterministic regressions;
`run_ev_stochastic_example` checks completion and final power release.

## Paired battery Monte Carlo experiment

```matlab
experiment = run_battery_monte_carlo(1:5);   % Development validation
% Later, when ready for a larger experiment:
% experiment = run_battery_monte_carlo(1:30);
```

Execution is serial because GPenSIM callbacks share global state. For each
seed the function generates exactly one workload, then passes that same table
to battery-off and battery-on scenarios. All other configuration fields are
identical. Each returned workload is checked against the original. This pairing
separates the battery comparison from differences in randomly sampled demand.

`experiment.runs` contains one row per seed/scenario. `paired_differences`
contains Battery minus NoBattery per seed. Negative differences improve waits,
queue length and completion time; positive differences improve throughput.
`percent_changes` divides each difference by the no-battery value and multiplies
by 100. A zero baseline yields NaN (undefined), not infinity or a fabricated zero.

P95 uses the toolbox-free `ev_percentile` helper: sort n observations, locate
rank `1 + (n-1)*p/100`, and interpolate between adjacent ranks (type-7 quantile).
This definition can differ from MATLAB percentile implementations using other
rank conventions. Empty workloads use zero waiting metrics.

`scenario_summary` reports mean, sample standard deviation, median, P25 and P75
for every numeric run metric. These summaries weight each run equally, not each
vehicle. `paired_summary` reports mean, sample standard deviation and median of
the matched differences. Its approximate normal 95% interval is:

```text
mean(d) +/- 1.96 * std(d) / sqrt(number of pairs)
```

These intervals are exploratory for five pairs; approximately 30 or more pairs
are intended for the later analysis. With only one pair CI endpoints are NaN.
They are not exact small-sample intervals or simultaneous intervals across all
metrics. `improvements` counts strict improvements; ties do not count.

Files are written into `results/battery_monte_carlo/` by default. Supply a second argument
to choose a separate output folder, e.g. `run_battery_monte_carlo(1:30,'mc_30')`.
Exports include the runs, paired differences, percent changes, scenario summary,
paired summary, improvement counts, and a complete experiment MAT file. A checkpoint
is saved after every scenario and includes completed rows and generated workloads;
the function does not automatically resume an existing checkpoint. Use a different
folder to preserve results from an earlier batch.

Batch mode is quiet and sets `retain_debug=false`: raw `sim` output and captured
transcripts are omitted from returned runs. The experiment retains summary rows
and workload tables, not ten/thirty/sixty raw simulator histories. GPenSIM still
builds its internal log for statistics; its time stepping is unchanged.

`test_ev_monte_carlo` checks percentile interpolation, pairing, summary statistics,
confidence intervals, and zero-baseline handling without running the simulator.

## Grid-capacity sensitivity (user-launched simulations)

Start with one seed: six full simulations, one workload shared by all six.

```matlab
setup_ev_project
experiment1 = run_grid_sensitivity(1);
% After inspecting the one-seed results:
experiment5 = run_grid_sensitivity(1:5);
```

The only station factors changed are grid capacity (150, 200, 250 kW) and
battery enabled/disabled. Battery-on always uses the same 100 kWh / 100 kW
discharge / 50 kW recharge design. Traffic and allocation rules are unchanged.
Runs are serial and quiet. An optional second argument selects an output folder.

Defaults are `results/grid_sensitivity_1/` and `results/grid_sensitivity_5/`.
These use `grid_sensitivity_*` filenames and do not overwrite battery Monte Carlo
exports. A checkpoint and runs CSV are saved after each full simulation. There
is no automatic resume; choose a new folder to preserve an older sensitivity run.

`runs` has one row per Seed x GridCapacityKW x BatteryEnabled (6 or 30 rows).
`summary` reports mean, sample standard deviation, median, P25 and P75 for each
metric at each grid/battery configuration. `paired_differences` matches battery
on and off by seed **within the same grid level**. `paired_effects` summarizes
those Battery-minus-NoBattery differences separately for each grid capacity.
`improvements` counts strict improvements (ties excluded). `report` and
`effect_report` are the compact report tables. All are exported to CSV.

Negative deltas improve waiting, queue length and completion time. Positive
throughput deltas improve throughput. No monotonic trend is assumed or forced.
Approximate normal confidence intervals are exploratory for five seeds; with
one seed their endpoints are NaN because variability cannot be estimated.

The runner checks identical workload tables, completion, final zero power,
grid limits, discharge limits and matching counts. Existing result assertions
check charger return. At 200 kW it also reads matching seed rows from
`results/battery_monte_carlo/battery_monte_carlo_runs.csv` and checks agreement
within the time-step tolerance. `baseline_checks` records the matched rows;
zero rows means no saved matching baseline was available, not a validated match.
It never edits that baseline file. A discrepancy stops the experiment rather
than changing the physical model to obtain the expected result.

`test_ev_grid_sensitivity` uses synthetic data and the supply helper only; it
does not execute a full simulation. The one-seed and five-seed experiments are
for you to launch explicitly.

## Demand sensitivity (user-launched simulations)

```matlab
setup_ev_project
experiment1 = run_demand_sensitivity(1);   % Six full simulations
% Later, after inspecting the one-seed validation:
experiment5 = run_demand_sensitivity(1:5); % Thirty full simulations
```

This separate experiment changes only the mean exponential interarrival time
(15, 10, 7.5 minutes) and battery enabled/disabled. Grid capacity stays at
200 kW, with the same chargers, battery design, vehicle probabilities and
energy ranges. The arrival horizon remains 480 minutes; service and recovery
can finish later. Counts are generated, not prescribed.

For every seed, demand is generated once **per demand level** and reused for
the OFF/ON pair. This means three workload tables and six runs per seed.
Workloads differ between demand levels, while the two battery configurations
at a given level receive identical arrivals, types and energy requests.
Reusing seed identifiers does not imply independent random streams across
demand levels. The paired battery effect is calculated within each level.

`experiment.workloads{seedIndex,levelIndex}` stores the exact traffic, with
columns ordered as `experiment.mean_interarrival_minutes = [15 10 7.5]`.
`runs` contains one row per Seed x MeanInterarrivalMinutes x BatteryEnabled.
Counts need only match within each pair, not across demand levels.

`summary` provides mean, sample standard deviation, median, P25 and P75 per
configuration, including vehicle count and battery energy use. All runs are
weighted equally. `paired_differences` and `paired_effects` contain Battery minus
NoBattery within each seed/demand combination and their per-level summaries.
`improvements` counts strict improvements; ties are excluded.

`report` includes vehicle count, waits, queue length, throughput, direct supply
waiting and battery use. `effect_report` shows the paired deltas alongside mean
battery energy use. `battery_usage` adds assisted-session counts for comparing
battery use with benefit. Higher throughput alongside longer waits is possible;
throughput alone does not measure service quality.

Exports and per-scenario checkpoints are saved separately to
`results/demand_sensitivity_1/` or `results/demand_sensitivity_5/`, using
`demand_sensitivity_*` filenames. An optional second argument selects another
folder. Existing Monte Carlo and grid-sensitivity results are never written.

At 10-minute demand the runner reads matched seed rows from the existing
battery Monte Carlo CSV and checks agreement within the configured time-step
tolerance. `baseline_checks` records matches. If the CSV or seed is absent,
there is no comparison for that seed; zero matched rows is not a passed baseline
validation. The remaining run checks enforce identical paired workloads,
completion, power bounds and final zero reservations.

`test_ev_demand_sensitivity` generates workloads and tests synthetic result
tables only. It does not run full simulations. Full one-seed validation is left
for you to launch. One-pair confidence intervals are NaN; five-pair approximate
normal intervals are exploratory.
