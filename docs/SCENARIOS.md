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
