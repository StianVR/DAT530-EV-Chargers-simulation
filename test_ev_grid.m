function test_ev_grid()
% Grid-aware admission tests, including effective-power fallback.
ratings = [22 50 150];
[~, a] = ev_charge_minutes(10, 22, 22);
[~, b] = ev_charge_minutes(20, 50, 50);
assert(a + b == 72);
assert(ev_choose_charger('C', [false false true], 150, ratings, 72, 200) == 0);
assert(ev_choose_charger('C', [false true true], 150, ratings, 22, 200) == 3);
% Fast exceeds the budget; Medium is the highest-ranked feasible fallback.
assert(ev_choose_charger('C', [true true true], 150, ratings, 72, 200) == 2);
assert(ev_choose_charger('C', [true false true], 150, ratings, 72, 200) == 1);
% A on Fast draws 22, not 150; exact-capacity admission is allowed.
assert(ev_choose_charger('A', [false false true], 22, ratings, 178, 200) == 3);
assert(ev_choose_charger('A', [true true true], 22, ratings, 179, 200) == 0);
% Exhaust every type, availability pattern and integer load up to capacity.
types = {'A', 'B', 'C'}; limits = [22 50 150];
for mask = 0:7
    available = logical(bitget(mask, 1:3));
    for type = 1:3
        for load = 0:200
            selected = ev_choose_charger(types{type}, available, limits(type), ratings, load, 200);
            feasible = available & (load + min(limits(type), ratings) <= 200);
            if selected == 0
                assert(~any(feasible));
            else
                assert(feasible(selected));
            end
        end
    end
end
disp('Grid admission, fallback, release-capacity and effective-power checks passed.');
end
