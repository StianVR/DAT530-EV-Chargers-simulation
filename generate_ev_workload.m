function workload = generate_ev_workload(scenario)
%GENERATE_EV_WORKLOAD Demand only: no station resource inputs are used.
if nargin == 0, scenario = ev_default_scenario(); end
defaults = ev_default_scenario();
for f = fieldnames(defaults)'
    if ~isfield(scenario,f{1}), scenario.(f{1}) = defaults.(f{1}); end
end
switch lower(scenario.workload_mode)
    case 'deterministic'
        types = scenario.vehicle_types(:);
        powers = scenario.vehicle_max_power_kW(:);
        energy = scenario.vehicle_energy_kWh(:);
        times = (1:numel(types))' * scenario.arrival_interval_minutes;
    case 'stochastic'
        validateattributes(scenario.random_seed, {'numeric'}, {'scalar','integer','nonnegative','<=',2^32-1});
        validateattributes(scenario.arrival_horizon_minutes, {'numeric'}, {'scalar','finite','nonnegative'});
        validateattributes(scenario.mean_interarrival_minutes, {'numeric'}, {'scalar','finite','positive'});
        p = scenario.vehicle_type_probabilities(:)';
        assert(numel(p)==3 && all(isfinite(p) & p>=0) && abs(sum(p)-1)<1e-10, ...
            'Type probabilities must be nonnegative and sum to one.');
        ranges = scenario.energy_ranges_kWh;
        assert(isequal(size(ranges),[3 2]) && all(isfinite(ranges(:))) ...
            && all(ranges(:,1)>0 & ranges(:,2)>=ranges(:,1)), 'Invalid energy ranges.');
        previousRng = rng;
        cleanup = onCleanup(@() rng(previousRng));
        rng(scenario.random_seed, 'twister');
        times = zeros(0,1); t = 0;
        while true
            t = t - scenario.mean_interarrival_minutes * log(max(rand(),realmin));
            if t > scenario.arrival_horizon_minutes, break; end
            times(end+1,1) = t; %#ok<AGROW>
        end
        n = numel(times);
        draw = rand(n,1);
        index = 1 + (draw >= p(1)) + (draw >= sum(p(1:2)));
        labels = {'A';'B';'C'}; ratings = [22;50;150];
        types = labels(index); powers = ratings(index);
        energy = ranges(index,1) + rand(n,1).*(ranges(index,2)-ranges(index,1));
    otherwise
        error('workload_mode must be deterministic or stochastic.');
end
workload = table((1:numel(times))',times,types,powers,energy, 'VariableNames', ...
    {'VehicleID','ArrivalTimeMinutes','Type','MaxPowerKW','EnergyRequiredKWh'});
workload.Properties.UserData = struct('mode',scenario.workload_mode, ...
    'random_seed',scenario.random_seed,'arrival_horizon_minutes',scenario.arrival_horizon_minutes);
end
