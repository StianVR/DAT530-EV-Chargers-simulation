function test_ev_recharge()
% Test the real recharge-completion hook without running GPenSIM.
global PN global_info;
oldPN = PN; oldInfo = global_info;
% Capture snapshots by value; the helper declares its own global bindings.
% A nested function could reference globals destroyed during parent exit.
cleanup = onCleanup(@() restore_recharge_globals(oldPN, oldInfo));
PN = struct();
PN.global_places = struct('name', {'pWait','pDone'});
PN.X = [0 6];
PN.global_transitions = struct('name','tRecharge');
missing = 22 * 16 / 60;
PN.Set_of_Firing_Times = missing / 50 * 60;
assert(abs(PN.Set_of_Firing_Times-7.04) < 1e-10);
PN.current_time = 172.71;
global_info = struct('activeVehicle',zeros(3,1),'currentGridLoad',0, ...
    'currentBatteryDischargeKW',0,'BATTERY_CAPACITY_KWH',100, ...
    'batteryEnergyKWh',100-missing,'currentBatteryChargeKW',50, ...
    'rechargedEnergyKWh',0,'batteryLog',zeros(0,4),'STOP_SIMULATION',false);
global_info.vehicleTypes = {'A';'B';'C';'A';'B';'C'};
COMMON_POST(struct('name','tRecharge'));
assert(global_info.batteryEnergyKWh == 100);
assert(abs(global_info.rechargedEnergyKWh-missing) < 1e-10);
assert(global_info.currentBatteryChargeKW == 0 && global_info.STOP_SIMULATION);
% Full battery must not enable another recharge firing.
[fire,~] = tRecharge_pre(struct());
assert(~fire);
disp('Recharge duration, full-capacity clamp, release and stop checks passed.');
end

function restore_recharge_globals(savedPN, savedInfo)
global PN global_info;
PN = savedPN;
global_info = savedInfo;
end
