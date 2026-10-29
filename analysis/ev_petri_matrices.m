function [Pre,Post,places,transitions,arcs] = ev_petri_matrices(net)
% Preserve self-loops by constructing input and output matrices separately.
assert(all(ismember(fieldnames(net),{'PN_name','set_of_Ps','set_of_Ts','set_of_As'})), ...
    'Unsupported definition fields: inspect special arcs before analysis.');
places=string(net.set_of_Ps(:)); transitions=string(net.set_of_Ts(:));
assert(numel(unique([places;transitions]))==numel(places)+numel(transitions));
a=reshape(net.set_of_As,3,[])';
arcs=table(string(a(:,1)),string(a(:,2)),cell2mat(a(:,3)), ...
    'VariableNames',{'Source','Destination','Weight'});
assert(all(isfinite(arcs.Weight) & arcs.Weight>0 & arcs.Weight==fix(arcs.Weight)));
Pre=zeros(numel(places),numel(transitions)); Post=Pre;
for k=1:height(arcs)
    p=find(places==arcs.Source(k)); t=find(transitions==arcs.Destination(k));
    if ~isempty(p) && ~isempty(t)
        Pre(p,t)=Pre(p,t)+arcs.Weight(k);
    else
        p=find(places==arcs.Destination(k)); t=find(transitions==arcs.Source(k));
        assert(~isempty(p) && ~isempty(t),'Arc is not place-to-transition or transition-to-place.');
        Post(p,t)=Post(p,t)+arcs.Weight(k);
    end
end
end
