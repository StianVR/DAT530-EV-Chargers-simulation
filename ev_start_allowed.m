function allowed = ev_start_allowed(charger)
%EV_START_ALLOWED Guard a charger allocation using the FIFO queue head.
% Read-only guard: reservations and duration changes belong in COMMON_POST.
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
selected = ev_choose_supply(global_info.vehicleTypes{head}, available, ...
    global_info.vehicleMaxKW(head), global_info.energyKWh(head), global_info.chargerPowerKW, ...
    global_info.currentGridLoad, global_info.GRID_CAPACITY, ...
    global_info.currentBatteryDischargeKW, global_info.BATTERY_MAX_DISCHARGE_KW, global_info.batteryEnergyKWh);
allowed = selected == charger;
end
