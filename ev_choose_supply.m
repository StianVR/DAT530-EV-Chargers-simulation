function chosen = ev_choose_supply(type, available, vehicleKW, energyKWh, ratings, load, capacity, discharge, maxDischarge, energy)
% Filter infeasible chargers, then apply the unchanged preference ordering.
for k = 1:3
    [minutes, power] = ev_charge_minutes(energyKWh, vehicleKW, ratings(k));
    available(k) = available(k) && ev_supply(power, minutes, load, capacity, discharge, maxDischarge, energy);
end
chosen = ev_choose_charger(type, available);
end
