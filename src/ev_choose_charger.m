function selected = ev_choose_charger(vehicleType, available, vehicleKW, chargerKW, loadKW, capacityKW)
%EV_CHOOSE_CHARGER Select the first available charger in preference order.
% Charger indices: 1=Normal, 2=Medium, 3=Fast. Zero means keep waiting.
% Optional grid arguments keep availability-only callers working.
if nargin == 2
    vehicleKW = inf; chargerKW = [22 50 150]; loadKW = 0; capacityKW = inf;
end
switch vehicleType
    case 'A'
        preference = [1 2 3];
    case 'B'
        preference = [2 3 1];
    case 'C'
        preference = [3 2 1];
    otherwise
        error('Unknown vehicle type: %s', vehicleType);
end
selected = 0;
for charger = preference
    if available(charger) && loadKW + min(vehicleKW, chargerKW(charger)) <= capacityKW + 1e-9
        selected = charger;
        return;
    end
end
end
