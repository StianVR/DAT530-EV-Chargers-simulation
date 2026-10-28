function test_ev_battery()
% Read-only admission and full-session energy reservation boundary tests.
[ok,g,b,e] = ev_supply(150,16,72,200,0,100,100);
assert(ok && g == 128 && b == 22 && abs(e-88/15) < 1e-10);
assert(~ev_supply(150,16,72,200,79,100,100));
assert(~ev_supply(150,16,72,200,0,100,e-0.001));
assert(ev_supply(150,16,72,200,78,100,e));
% Empty battery does not prevent a grid-only session.
assert(ev_supply(22,60,100,200,0,100,0));
% Reserving the first session's energy prevents reusing it for another.
remaining = e;
remaining = remaining-e;
assert(~ev_supply(150,16,72,200,22,100,remaining));
ratings = [22;50;150];
assert(ev_choose_supply('C',[0 0 1],150,40,ratings,72,200,0,100,100) == 3);
assert(ev_choose_supply('C',[0 0 1],150,40,ratings,72,200,0,100,0) == 0);
assert(ev_choose_supply('C',[0 1 1],150,40,ratings,72,200,0,100,0) == 2);
% A on Fast uses its effective 22 kW, not the 150 kW charger rating.
[ok,g,b,e] = ev_supply(22,600/11,190,200,0,100,100);
assert(ok && g == 10 && b == 12 && abs(e-120/11) < 1e-9);
disp('Battery split, power, energy, concurrent-budget and fallback tests passed.');
end
