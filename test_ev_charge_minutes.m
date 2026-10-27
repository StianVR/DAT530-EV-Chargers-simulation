function test_ev_charge_minutes()
% All nine type/charger combinations; rows A/B/C, columns Normal/Medium/Fast.
vehicleKW = [22 50 150];
chargerKW = [22 50 150];
expected = [600/11 600/11 600/11; 600/11 24 24; 600/11 24 8];
for vehicle = 1:3
    for charger = 1:3
        [duration, power] = ev_charge_minutes(20, vehicleKW(vehicle), chargerKW(charger));
        assert(abs(duration - expected(vehicle, charger)) < 1e-10);
        assert(abs(power * duration / 60 - 20) < 1e-10);
    end
end
disp('All nine charging-duration and energy checks passed.');
end
