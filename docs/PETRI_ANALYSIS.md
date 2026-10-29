# Petri-net structural analysis

From the project root:

```matlab
setup_ev_project;
result = analyze_ev_petri_net();
test_ev_petri_analysis;
```

These commands do not run a simulation. The utility reads `ev_basic_pdf()`
and uses the six-vehicle `ev_default_scenario()` initial configuration.
The initial marking assignment mirrors `src/ev_simulate_scenario.m`; it is
kept separate to avoid invoking the simulation engine. If that assignment
changes, update the analysis assignment and regression checks too.

Outputs are in `results/petri_analysis/`: inventory tables, labelled Pre,
Post and incidence matrices, P-invariants, reachable markings, graph edges,
text summaries and `petri_analysis.mat`. State IDs in the edge table are
one-based row numbers in `reachable_markings.csv`; transition IDs follow
`transitions.csv`. Invariant coefficients are columns in `p_invariants.csv`;
their conserved constants and equations are in `structural_summary.txt`.

## Matrices and model class

The actual definition has 11 places, 8 transitions and 30 directed unit-weight
arcs. Its structure is an ordinary P/T net with self-loops and no inhibitor,
reset or other special arcs. Unsupported definition fields are rejected rather
than silently ignored. It is not a colored-token net: vehicle identity is
maintained externally in MATLAB.

Matrix rows are places and columns are transitions. An arc from place p to
transition t contributes its weight to `Pre(p,t)`. The reverse arc contributes
to `Post(p,t)`. `C = Post - Pre` records net token change. Keeping Pre and Post
separate matters: a self-loop has zero net change but still requires a token
to enable its transition. Atomic firing is enabled when `m >= Pre(:,t)` and
produces `m + C(:,t)`.

The executing model additionally has positive firing times, dynamically updated
charging/recharge durations and MATLAB PRE/POST guards/actions. These are not
represented in the structural matrices.

## Conservation and bounds

A P-invariant is a column y with `y' * C = 0`. Therefore `y' * m` stays
constant after every atomic firing. Six independent invariants are found:

- `pToArrive + pWait + pChargeNormal + pChargeMedium + pChargeFast + pDone = N`.
- `pAvailNormal + pChargeNormal = 1`.
- `pAvailMedium + pChargeMedium = 1`.
- `pAvailFast + pChargeFast = 1`.
- `pArrivalReady = 1`.
- `pDispatch = 1`.

Thus pending, waiting and completed vehicle places are bounded by N, each
charging/available resource place by 1, and each control place by 1. For six
vehicles the net is bounded but not safe: safety requires every reachable
place marking to be at most one, whereas pDone reaches six. For any fixed
finite generated workload, the same conservation argument gives finite bounds;
it does not give a workload-independent bound as N grows arbitrarily.

These equations describe atomic P/T markings. GPenSIM removes tokens when a
timed firing starts and deposits them later. During a firing, include tokens
in flight/reserved by transitions when interpreting conservation; the visible
`PN.X` alone need not satisfy these equations at every simulator instant.

## Reachability, termination and liveness

The default exploration is complete with 146 distinct markings. Every marking
has a path to the vehicle completion marking: pDone=6, all three availability
places=1, pArrivalReady=pDispatch=1, and all other places=0.

**That marking is not a dead marking of the full unguarded net.** tRecharge
consumes and returns pDispatch, so it is enabled in every reachable marking,
including completion. There are zero full-net dead markings. The diagnostic
`UnintendedDeadlockFound` instead checks for states without an enabled
vehicle-processing transition before vehicle completion; none are found.
If tRecharge is excluded from that diagnostic, the sole vehicle completion
marking is an intended terminal dead marking of the vehicle-flow projection.

Strict liveness means that from every reachable marking each transition can
eventually fire again. This net is not strictly live: once all vehicles finish,
tArrival and every charging transition are permanently disabled. Successful
finite termination does not imply liveness. Nor does a completion path imply
that all schedules finish: the unguarded recharge self-loop can repeat forever.

In the actual implementation, `tRecharge_pre` only permits recharge once all
vehicles finish and the battery lacks energy. `COMMON_POST` restores battery
energy and sets STOP_SIMULATION after recharge, or stops at EV completion if
the battery is already full. That is operational termination, not a claim
that the unguarded full net has reached a dead marking.

For this bounded net, complete reachability also answers coverability: a target
marking is coverable exactly when some enumerated marking is componentwise
greater than or equal to it. No omega markings or separate acceleration tree
are needed. This statement applies only when `ReachabilityComplete` is true.

## Installed GPenSIM facilities and limits

The installed `pinvariant(PN)` and `retree(pni,max_states)` source was inspected,
including `gpensim_2_PNCT`, `PNCT_pinvar`, `build_retree`, `enabled_transition`
and `new_marking`. The utility supplies their documented matrix/global fields
without calling `pnstruct`, `initialdynamics` or `gpensim`. pinvariant supplies
integer nonnegative semiflows. retree independently cross-checks the unique
markings against a base-MATLAB breadth-first exploration. Its dummy unit times
and zero costs are not used to infer real durations. PN is restored with a
separate cleanup function; global_info is untouched.

`cotree` also exists, but its interface has no state cutoff. We use bounded
reachability instead. The toolbox's general printed heuristic that no terminal
states implies liveness is not used: the recharge loop illustrates why that
heuristic is insufficient. The retree time/cost printing branch is captured,
not treated as a formal conclusion.

The independent BFS has a hard `maximum_state_count` cutoff (default 10000).
GPenSIM's retree limits tree rows, including duplicate markings, rather than
unique states, and can overshoot by one expansion. Only a completed BFS is
used to claim exhaustive results. At cutoff, saved markings are a partial set,
observed maxima are only lower bounds on reachable maxima, and undecided
deadlock/progress properties are NaN. Invariant bounds remain valid.

```matlab
options.maximum_state_count = 1000;
options.output_directory = fullfile(pwd,'results','petri_analysis_custom');
result = analyze_ev_petri_net(options);
```

If the inspected GPenSIM functions are unavailable, a small-net binary
nonnegative-invariant search and BFS work in base MATLAB. For this net the
six independent binary invariants span the invariant space. Binary enumeration
does not find arbitrary integer invariants of general nets; its residuals,
dimension and bounds are reported rather than assuming completeness. It is
restricted to at most 20 places. Set `options.use_gpensim=false` to test it.

## Limits of the conclusion

Structural states do not encode FIFO vehicle identity, type, requested kWh,
charger preferences, grid load, battery energy, power reservations, timers or
the stop flag. Guards restrict the structurally available choices and may
introduce blocking that this analysis cannot detect. Therefore the absence of
unintended structural vehicle-flow deadlocks is **not a proof of operational
deadlock freedom for the full MATLAB implementation**. Tests and performance
simulations complement these structural results.

The helper test checks arc weights, dimensions, exact C, invariant residuals
and initial/final constants, legal graph edges, resource invariants, the
146-state regression, a cutoff on an unbounded toy net, self-loops, fallback
agreement and preservation of globals. No simulation parameters or callbacks
are changed.
