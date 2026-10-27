function allowed = ev_start_allowed(charger)
%EV_START_ALLOWED Guard a charger allocation using the FIFO queue head.
% Rejected guards change nothing. An accepted guard configures the next
% charging duration but never removes tokens or advances the FIFO sequence.
global PN global_info;
chargerNames = {'Normal', 'Medium', 'Fast'};
transitionNames = {PN.global_transitions.name};
placeNames = {PN.global_places.name};
allocated = 0;
available = false(1, 3);
for k = 1:3
    tid = find(strcmp(transitionNames, ['tStart' chargerNames{k}]));
    % Count completed allocations AND allocations currently in progress.
    % Otherwise two chargers could select the same FIFO vehicle.
    allocated = allocated + PN.global_transitions(tid).times_fired ...
        + PN.Firing_Transitions(tid);
    pid = find(strcmp(placeNames, ['pAvail' chargerNames{k}]));
    available(k) = PN.X(pid) > 0;
end
waitId = find(strcmp(placeNames, 'pWait'));
allowed = false;
head = allocated + 1;
if PN.X(waitId) == 0 || head > numel(global_info.vehicleTypes)
    return;
end
selected = ev_choose_charger(global_info.vehicleTypes{head}, available);
allowed = selected == charger;
if allowed
    duration = ev_charge_minutes(global_info.energyKWh(head), ...
        global_info.vehicleMaxKW(head), global_info.chargerPowerKW(charger));
    doneId = find(strcmp(transitionNames, ['tDone' chargerNames{charger}]));
    % get_firingtime reads this numeric cache when scheduling a firing.
    % Update the transition description too so both representations agree.
    PN.Set_of_Firing_Times(doneId) = duration;
    PN.global_transitions(doneId).firing_time = duration;
end
end
