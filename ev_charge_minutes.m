function [minutes, effectiveKW] = ev_charge_minutes(energyKWh, vehicleKW, chargerKW)
%EV_CHARGE_MINUTES Constant-power charging, without losses or SOC taper.
assert(all(energyKWh(:) > 0) && all(vehicleKW(:) > 0) ...
    && all(chargerKW(:) > 0), 'Energy and power must be positive.');
effectiveKW = min(vehicleKW, chargerKW);
minutes = 60 .* energyKWh ./ effectiveKW;
end
