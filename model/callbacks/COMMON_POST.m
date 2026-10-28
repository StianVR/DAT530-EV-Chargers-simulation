function COMMON_POST(transition)
% After token deposition: reserve on allocation, release on completion.
global PN global_info;
if strcmp(transition.name, 'tRecharge')
    names = {PN.global_places.name};
    assert(PN.X(strcmp(names,'pWait')) == 0 && all(global_info.activeVehicle == 0));
    assert(PN.X(strcmp(names,'pDone')) == numel(global_info.vehicleTypes));
    assert(global_info.currentGridLoad == 0 && global_info.currentBatteryDischargeKW == 0);
    tid = find(strcmp({PN.global_transitions.name}, 'tRecharge'));
    duration = PN.Set_of_Firing_Times(tid);
    added = min(global_info.BATTERY_CAPACITY_KWH - global_info.batteryEnergyKWh, ...
        global_info.currentBatteryChargeKW * duration / 60);
    global_info.batteryEnergyKWh = min(global_info.BATTERY_CAPACITY_KWH, ...
        global_info.batteryEnergyKWh + added);
    assert(abs(global_info.batteryEnergyKWh-global_info.BATTERY_CAPACITY_KWH) < 1e-8);
    global_info.batteryEnergyKWh = global_info.BATTERY_CAPACITY_KWH;
    global_info.rechargedEnergyKWh = global_info.rechargedEnergyKWh + added;
    global_info.currentBatteryChargeKW = 0;
    global_info.batteryFullTime = PN.current_time;
    global_info.batteryLog(end+1,:) = [PN.current_time global_info.batteryEnergyKWh 0 0];
    global_info.STOP_SIMULATION = true;
    fprintf('Minute %.3f: battery full; %.6f kWh recharged; recharge grid load released\n', PN.current_time, added);
    return;
end
names = {'Normal', 'Medium', 'Fast'};
start = find(strcmp(transition.name, strcat('tStart', names)));
finish = find(strcmp(transition.name, strcat('tDone', names)));
if isempty(start) && isempty(finish), return; end
before = global_info.currentGridLoad;
energyBefore = global_info.batteryEnergyKWh;
if ~isempty(start)
    charger = start;
    assert(global_info.activeVehicle(charger) == 0, 'Duplicate grid reservation.');
    % pDispatch permits only one allocation in progress. Its completed
    % count identifies the FIFO vehicle whose allocation just finished.
    transitionNames = {PN.global_transitions.name};
    vehicle = 0;
    for k = 1:3
        tid = find(strcmp(transitionNames, ['tStart' names{k}]));
        vehicle = vehicle + PN.global_transitions(tid).times_fired;
    end
    [duration, power] = ev_charge_minutes(global_info.energyKWh(vehicle), ...
        global_info.vehicleMaxKW(vehicle), global_info.chargerPowerKW(charger));
    [ok, gridPower, batteryPower, batteryEnergy] = ev_supply(power, duration, before, ...
        global_info.GRID_CAPACITY, global_info.currentBatteryDischargeKW, ...
        global_info.BATTERY_MAX_DISCHARGE_KW, global_info.batteryEnergyKWh);
    assert(ok, 'Supply reservation exceeds power or energy availability.');
    doneId = find(strcmp(transitionNames, ['tDone' names{charger}]));
    PN.Set_of_Firing_Times(doneId) = duration;
    PN.global_transitions(doneId).firing_time = duration;
    global_info.activeVehicle(charger) = vehicle;
    global_info.activePowerKW(charger) = power;
    global_info.activeGridKW(charger) = gridPower;
    global_info.activeBatteryKW(charger) = batteryPower;
    global_info.activeBatteryEnergyKWh(charger) = batteryEnergy;
    global_info.vehicleSupply(vehicle, :) = [gridPower batteryPower batteryEnergy];
    global_info.batteryEnergyKWh = max(0, energyBefore - batteryEnergy);
    change = gridPower;
    action = 'starting';
else
    charger = finish;
    vehicle = global_info.activeVehicle(charger);
    assert(vehicle > 0 && global_info.activePowerKW(charger) > 0, 'Duplicate grid release.');
    change = -global_info.activeGridKW(charger);
    global_info.activeGridKW(charger) = 0;
    global_info.activeBatteryKW(charger) = 0;
    global_info.activeBatteryEnergyKWh(charger) = 0;
    global_info.activeVehicle(charger) = 0;
    global_info.activePowerKW(charger) = 0;
    action = 'finishing';
end
global_info.currentGridLoad = sum(global_info.activeGridKW);
global_info.currentBatteryDischargeKW = sum(global_info.activeBatteryKW);
assert(all(abs(global_info.activeGridKW + global_info.activeBatteryKW - global_info.activePowerKW) < 1e-9));
assert(global_info.currentBatteryDischargeKW >= 0 && ...
    global_info.currentBatteryDischargeKW <= global_info.BATTERY_MAX_DISCHARGE_KW + 1e-9);
assert(global_info.batteryEnergyKWh >= 0 && global_info.batteryEnergyKWh <= global_info.BATTERY_CAPACITY_KWH);
if isempty(start)
    assert(global_info.batteryEnergyKWh == energyBefore, 'Completion must not change battery energy.');
elseif batteryPower == 0
    assert(global_info.batteryEnergyKWh == energyBefore);
end
global_info.peakBatteryDischargeKW = max(global_info.peakBatteryDischargeKW, global_info.currentBatteryDischargeKW);
global_info.minimumBatteryEnergyKWh = min(global_info.minimumBatteryEnergyKWh, global_info.batteryEnergyKWh);
global_info.batteryLog(end+1,:) = [PN.current_time global_info.batteryEnergyKWh global_info.currentBatteryDischargeKW global_info.currentBatteryChargeKW];
after = global_info.currentGridLoad;
assert(after >= -1e-9 && after <= global_info.GRID_CAPACITY + 1e-9, ...
    'Grid load outside allowed bounds.');
assert(abs(after - before - change) < 1e-9, 'Grid accounting mismatch.');
global_info.peakGridLoad = max(global_info.peakGridLoad, after);
global_info.gridLog(end+1, :) = [PN.current_time vehicle charger change before after];
fprintf('Minute %.3f: vehicle %d (%s) %s on %s; power change %+.1f kW; grid %.1f -> %.1f kW\n', ...
    PN.current_time, vehicle, global_info.vehicleTypes{vehicle}, action, names{charger}, change, before, after);
fprintf('  Battery: %.3f kW reserved; %.6f kWh unreserved energy remains\n', ...
    global_info.currentBatteryDischargeKW, global_info.batteryEnergyKWh);
doneId = find(strcmp({PN.global_places.name}, 'pDone'));
target = numel(global_info.vehicleTypes); % Six for A, B, C, A, B, C.
if PN.X(doneId) >= target
    assert(after == 0 && all(global_info.activeVehicle == 0), 'Power remains after completion.');
    % GPenSIM checks this flag at the end of its current loop, after logging
    % the final completion. No charger or vehicle tokens are modified here.
    global_info.lastVehicleCompletionTime = PN.current_time;
    missing = global_info.BATTERY_CAPACITY_KWH - global_info.batteryEnergyKWh;
    if missing <= 1e-9
        global_info.batteryFullTime = PN.current_time;
        global_info.STOP_SIMULATION = true;
    else
        % This post action follows the actual last EV completion. The
        % recharge transition starts in the next loop at the same time.
        chargePower = min(global_info.BATTERY_MAX_CHARGE_KW, global_info.GRID_CAPACITY);
        assert(chargePower > 0 && chargePower <= global_info.BATTERY_MAX_CHARGE_KW);
        global_info.currentBatteryChargeKW = chargePower;
        global_info.rechargeStartTime = PN.current_time;
        tid = find(strcmp({PN.global_transitions.name}, 'tRecharge'));
        duration = missing / chargePower * 60;
        PN.Set_of_Firing_Times(tid) = duration;
        PN.global_transitions(tid).firing_time = duration;
        global_info.batteryLog(end+1,:) = [PN.current_time global_info.batteryEnergyKWh 0 chargePower];
        fprintf('Minute %.3f: idle recharge starts at %.1f kW for %.6f minutes\n', PN.current_time, chargePower, duration);
    end
end
end
