function test_ev_petri_analysis()
% Structural checks only: no simulation and no experiment execution.
global PN global_info;
oldPN=PN; oldInfo=global_info;
options=struct('output_directory',tempname,'maximum_state_count',10000);
r=analyze_ev_petri_net(options);
assert(isequaln(PN,oldPN) && isequaln(global_info,oldInfo),'Analysis changed simulation globals.');
assert(isequal(size(r.Pre),[11 8]) && isequal(r.C,r.Post-r.Pre));
assert(height(r.arcs)==30 && all(r.arcs.Weight==1));
% Check every definition arc independently against its corresponding matrix.
for k=1:height(r.arcs)
    i=find(r.places.Place==r.arcs.Source(k)); j=find(r.transitions==r.arcs.Destination(k));
    if ~isempty(i), assert(r.Pre(i,j)==r.arcs.Weight(k));
    else
        i=find(r.places.Place==r.arcs.Destination(k)); j=find(r.transitions==r.arcs.Source(k));
        assert(r.Post(i,j)==r.arcs.Weight(k));
    end
end
assert(all(all(r.invariants'*r.C==0)) && rank(r.invariants)==6);
assert(all(all(r.reachability.markings*r.invariants==r.invariantConstants')));
assert(all(r.places.InitialTokens'*r.invariants==r.places.VehicleTerminalTokens'*r.invariants));
for type=["Normal","Medium","Fast"]
    y=double(ismember(r.places.Place,["pAvail"+type,"pCharge"+type]));
    assert(all(y'*r.C==0) && y'*r.places.InitialTokens==1);
end
assert(r.summary.Bounded && ~r.summary.Safe && ~r.summary.StrictlyLive);
assert(r.summary.ReachabilityComplete && r.summary.ReachabilityStateCount==146);
assert(r.summary.IntendedTerminalMarkingExists && ~r.summary.UnintendedDeadlockFound);
assert(r.summary.AllStatesCanReachVehicleCompletion && r.summary.StructuralDeadMarkings==0);
% Independently check edges are legal atomic firings.
for k=1:size(r.reachability.edges,1)
    e=r.reachability.edges(k,:); before=r.reachability.markings(e(1),:)';
    after=r.reachability.markings(e(2),:)';
    assert(all(before>=r.Pre(:,e(3))) && isequal(after,before+r.C(:,e(3))));
end
% Self-loop remains enabled but cannot make the resource unbounded.
toy=ev_petri_reachability(1,1,1,5);
assert(toy.complete && size(toy.markings,1)==1 && toy.enabled);
% An unbounded toy source must stop at the configured state cutoff.
toy=ev_petri_reachability(0,1,0,3);
assert(~toy.complete && size(toy.markings,1)==3);
% A small cutoff must report unknown properties, not claim completeness.
options.maximum_state_count=2; options.use_gpensim=false;
partial=analyze_ev_petri_net(options);
assert(~partial.summary.ReachabilityComplete && isnan(partial.summary.UnintendedDeadlockFound));
% Base MATLAB fallback must agree with installed toolbox conclusions.
options.maximum_state_count=10000;
fallback=analyze_ev_petri_net(options);
assert(fallback.summary.Bounded && fallback.summary.NumberOfPInvariants==6);
assert(isequal(fallback.places.InvariantBound,r.places.InvariantBound));
assert(isequaln(PN,oldPN) && isequaln(global_info,oldInfo));
disp('Structural matrices, invariants, reachability, cutoff, fallback and global-state checks passed.');
end
