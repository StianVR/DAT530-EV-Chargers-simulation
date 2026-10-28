function [fire, transition] = tStartNormal_pre(transition)
% GPenSIM calls this before consuming the allocation's input tokens.
fire = ev_start_allowed(1);
end
