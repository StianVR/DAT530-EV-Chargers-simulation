# Report analysis from saved experiments

No simulation is called by this pipeline. From the project root:

```matlab
setup_ev_project
analysis = generate_report_figures();
```

The default sources are explicit development datasets:

| Family | CSV source |
|---|---|
| Battery comparison | `results/battery_monte_carlo/battery_monte_carlo_runs.csv` |
| Grid sensitivity | `results/grid_sensitivity_1/grid_sensitivity_runs.csv` |
| Demand sensitivity | `results/demand_sensitivity_1/demand_sensitivity_runs.csv` |

The function prints the source paths and seed counts. It does not select the
largest/newest folder or substitute another experiment if a source is missing.
A missing file is reported and its plots/table are skipped. Malformed columns,
duplicate/missing pairs, incomplete configurations or nonfinite metrics cause
a clear error rather than generating a misleading partial-experiment plot.

## Select completed larger experiments

After the separate 30-seed battery experiment finishes, point explicitly to it:

```matlab
options.battery_directory = fullfile(pwd,'results','battery_monte_carlo_30');
options.grid_directory = fullfile(pwd,'results','grid_sensitivity_5');
options.demand_directory = fullfile(pwd,'results','demand_sensitivity_5');
options.output_directory = fullfile(pwd,'results','figures_30');
analysis = generate_report_figures(options);
```

Use your actual folder names. Omit a field to retain its documented default.
If a five-seed sensitivity file is not yet available, the corresponding plots
are skipped; the one-seed results are not silently substituted.

## Statistics and interpretation

Every seed receives equal weight. Battery states are grouped separately; grid
levels are ordered 150, 200, 250 kW. Demand categories are Low (15 minutes),
Baseline (10 minutes), High (7.5 minutes). These numbers are mean exponential
interarrival times, not fixed vehicle counts.

Error bars are **one sample standard deviation across seeds**, not confidence
intervals and not variation among vehicles in one run. The paired experiment's
confidence interval describes Battery-minus-NoBattery differences; it is not
appropriate to attach that interval to individual scenario bars. With one seed,
standard deviations in summary CSVs are NaN and figures omit error bars and
explicitly identify the single workload.

`P95Wait` averages each run's within-run 95th-percentile waiting time. It is not
the percentile of pooled vehicles or the percentile of run means. `MaxQueue`
is the average of each run's maximum queue length. Throughput is vehicles/hour;
waits are minutes; grid capacities are kW; battery energy use is kWh.

## Outputs

The default output directory is `results/figures/`. Five figures are exported
as 300-dpi PNG, vector PDF and editable MATLAB FIG:

- `battery_mean_wait`
- `grid_vs_mean_wait`
- `grid_vs_battery_use`
- `demand_vs_mean_wait`
- `demand_vs_p95_wait`

Summary tables are both returned (`analysis.battery`, `.grid`, `.demand`) and
exported as `battery_summary.csv`, `grid_summary.csv`, `demand_summary.csv`.
`analysis_sources.csv` records source files, load/skip status, rows and seeds;
`report_analysis.mat` stores the returned analysis structure and settings.

Rerunning updates derived files only, never the raw experiment CSVs. Choose a
new output directory to preserve an earlier report set. If you reuse a folder
with missing sources, old figure files from earlier runs are not deleted: use
the current source manifest to identify what was generated, or use a new folder.

`test_ev_report_analysis` checks saved-file aggregation and validation without
running simulations. One-seed sensitivity figures are development illustrations;
use the later multi-seed outputs for conclusions about variability.
