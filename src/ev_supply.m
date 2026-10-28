function [ok, gridKW, batteryKW, batteryKWh] = ev_supply(power, minutes, load, capacity, discharge, maxDischarge, energy)
% Read-only admission calculation; reserve energy for the entire session.
gridKW = min(power, max(0, capacity - load));
batteryKW = power - gridKW;
batteryKWh = batteryKW * minutes / 60;
ok = discharge + batteryKW <= maxDischarge + 1e-9 ...
    && batteryKWh <= energy + 1e-9;
end
