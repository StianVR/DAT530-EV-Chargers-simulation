function test_ev_selection()
% Check all availability combinations against each type's preference.
availability = logical([0 0 0; 1 0 0; 0 1 0; 0 0 1; ...
    1 1 0; 1 0 1; 0 1 1; 1 1 1]);
expected = [0 0 0; 1 1 1; 2 2 2; 3 3 3; ...
    1 2 2; 1 3 3; 2 2 3; 1 2 3];
types = {'A', 'B', 'C'};
for row = 1:size(availability, 1)
    for type = 1:3
        assert(ev_choose_charger(types{type}, availability(row, :)) ...
            == expected(row, type), 'Incorrect charger preference or fallback.');
    end
end
disp('All 24 charger-selection cases passed.');
end
