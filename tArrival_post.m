function tArrival_post(~)
% Consume the fixed schedule, never draw random numbers in a callback.
global PN global_info;
if ~global_info.useArrivalSchedule, return; end
tid = find(strcmp({PN.global_transitions.name},'tArrival'));
next = PN.global_transitions(tid).times_fired + 1;
if next <= numel(global_info.arrivalTimes)
    % Account for rounding at previous arrival, avoiding cumulative drift.
    % Extremely close arrivals are serialized at the simulator's resolution.
    duration = max(1e-9, global_info.arrivalTimes(next)-PN.current_time);
    PN.Set_of_Firing_Times(tid) = duration;
    PN.global_transitions(tid).firing_time = duration;
end
end
