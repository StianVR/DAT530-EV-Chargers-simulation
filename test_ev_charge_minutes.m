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
% Individual deterministic requests, checked against every charger rating.
energy = [10; 20; 40; 20; 30; 50];
limits = [22; 50; 150; 22; 50; 150];
expectedIndividual = [300/11 300/11 300/11; ...
    600/11 24 24; 1200/11 48 16; 600/11 600/11 600/11; ...
    900/11 36 36; 1500/11 60 20];
for charger = 1:3
    [duration, power] = ev_charge_minutes(energy, limits, ...
        repmat(chargerKW(charger), 6, 1));
    assert(all(abs(duration - expectedIndividual(:, charger)) < 1e-10));
    assert(all(abs(power .* duration / 60 - energy) < 1e-10));
end
disp('All 18 individual-energy charging cases passed.');
end
