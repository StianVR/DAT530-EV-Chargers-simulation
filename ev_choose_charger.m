function selected = ev_choose_charger(vehicleType, available)
%EV_CHOOSE_CHARGER Select the first available charger in preference order.
% Charger indices: 1=Normal, 2=Medium, 3=Fast. Zero means keep waiting.
% All three are compatible for this milestone; kW does not set duration.
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
    if available(charger)
        selected = charger;
        return;
    end
end
end
