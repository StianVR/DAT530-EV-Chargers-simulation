function [fire, transition] = tStartMedium_pre(transition)
% Returning false leaves the waiting vehicle and charger tokens untouched.
fire = ev_start_allowed(2);
end
