function COMMON_POST(transition)
%COMMON_POST GPenSIM hook called after a transition deposits output tokens.
% Only charging completions can finish the EV simulation.
if ~any(strcmp(transition.name, {'tDoneNormal', 'tDoneMedium', 'tDoneFast'}))
    return;
end
global PN global_info;
doneId = find(strcmp({PN.global_places.name}, 'pDone'));
target = numel(global_info.vehicleTypes); % Six for A, B, C, A, B, C.
if PN.X(doneId) >= target
    % GPenSIM checks this flag at the end of its current loop, after logging
    % the final completion. No charger or vehicle tokens are modified here.
    global_info.STOP_SIMULATION = true;
end
end
