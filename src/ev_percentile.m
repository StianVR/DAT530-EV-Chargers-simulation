function value = ev_percentile(values, percent)
%EV_PERCENTILE Toolbox-free type-7 quantile (linear interpolation).
% Sorted x: position = 1 + (n-1)*percent/100; interpolate adjacent ranks.
% Empty waits use zero so a zero-demand run has zero waiting metrics.
validateattributes(percent, {'numeric'}, {'scalar','>=',0,'<=',100});
x = sort(values(:));
assert(all(isfinite(x)), 'Percentile input must be finite.');
if isempty(x), value = 0; return; end
position = 1 + (numel(x)-1)*percent/100;
lo = floor(position); hi = ceil(position);
value = x(lo) + (position-lo)*(x(hi)-x(lo));
end
