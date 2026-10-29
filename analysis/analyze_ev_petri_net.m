function result = analyze_ev_petri_net(options)
%ANALYZE_EV_PETRI_NET Structural analysis only; never calls gpensim.
% Initial marking mirrors ev_simulate_scenario for ev_default_scenario.
if nargin<1, options=struct(); end
root=fileparts(fileparts(mfilename('fullpath')));
if ~isfield(options,'output_directory'), options.output_directory=fullfile(root,'results','petri_analysis'); end
if ~isfield(options,'maximum_state_count'), options.maximum_state_count=10000; end
if ~isfield(options,'use_gpensim'), options.use_gpensim=true; end
net=ev_basic_pdf(); s=ev_default_scenario(); N=numel(s.vehicle_types);
[Pre,Post,p,t,arcs]=ev_petri_matrices(net); C=Post-Pre;
m0=zeros(numel(p),1);
initialNames=["pToArrive","pArrivalReady","pDispatch","pAvailNormal","pAvailMedium","pAvailFast"];
initialValues=[N 1 1 s.normal_chargers s.medium_chargers s.fast_chargers];
for k=1:numel(initialNames)
    assert(nnz(p==initialNames(k))==1,'Initial marking no longer matches definition.');
    m0(p==initialNames(k))=initialValues(k);
end
terminal=m0; terminal(p=="pToArrive")=0; terminal(p=="pDone")=N;
r=ev_petri_reachability(Pre,Post,m0,options.maximum_state_count);
% Enumerate minimal binary nonnegative invariants for this small net.
% No claim that binary enumeration finds all integer semiflows in general.
assert(numel(p)<=20,'Binary invariant fallback is restricted to small nets.');
Y=zeros(numel(p),0);
for mask=1:2^numel(p)-1
    y=double(bitget(mask,1:numel(p)))';
    if all(y'*C==0) && ~any(all(Y<=y,1)), Y(:,end+1)=y; end %#ok<AGROW>
end
toolkit="Base MATLAB: binary nonnegative invariants and bounded BFS";
if options.use_gpensim && exist('pinvariant','file')==2 && exist('retree','file')==2
    [toolY,tree]=toolkit_analysis(Pre,Post,p,t,m0,options.maximum_state_count);
    assert(all(toolY(:)>=0) && all(toolY(:)==fix(toolY(:))) && all(all(toolY'*C==0)));
    Y=toolY;
    if r.complete && size(tree,1)<options.maximum_state_count
        assert(isequal(sortrows(unique(tree(:,1:numel(p)),'rows')),sortrows(r.markings)), ...
            'GPenSIM retree and matrix BFS disagree.');
        toolkit="GPenSIM pinvariant; retree independently agrees with complete matrix BFS";
    else
        toolkit="GPenSIM pinvariant and capped retree; matrix BFS determines completeness";
    end
end
assert(all(all(Y'*C==0)));
constants=Y'*m0; bounds=inf(numel(p),1);
for j=1:size(Y,2)
    ids=Y(:,j)>0; bounds(ids)=min(bounds(ids),floor(constants(j)./Y(ids,j)));
end
isTerminal=all(r.markings==terminal',2);
recharge=find(t=="tRecharge"); assert(isscalar(recharge));
vehicleTransitions=setdiff(1:numel(t),recharge);
summary=struct('NumberOfPlaces',numel(p),'NumberOfTransitions',numel(t), ...
    'NumberOfArcs',height(arcs),'StructuralPNClass',"Ordinary P/T net with self-loops", ...
    'UsesTimedTransitions',true,'UsesGuardsOrCallbacks',true,'Bounded',all(isfinite(bounds)), ...
    'Safe',NaN,'StrictlyLive',NaN,'IntendedTerminalMarkingExists',any(isTerminal), ...
    'UnintendedDeadlockFound',NaN,'NumberOfPInvariants',size(Y,2), ...
    'InvariantSpaceDimension',numel(p)-rank(C),'ReachabilityStateCount',size(r.markings,1), ...
    'ReachabilityComplete',r.complete,'CoverabilityStatus',"Incomplete exploration", ...
    'AllStatesCanReachVehicleCompletion',NaN,'StructuralDeadMarkings',NaN, ...
    'AnalysisMethod',toolkit);
assert(all(arcs.Weight==1),'Update class label for weighted arcs.');
if ~r.complete && ~any(isTerminal), summary.IntendedTerminalMarkingExists=NaN; end
if any(r.markings(:)>1), summary.Safe=false; elseif r.complete, summary.Safe=true; end
if any(isTerminal), summary.StrictlyLive=false; end % arrival cannot fire again
if r.complete
    dead=~any(r.enabled(:,vehicleTransitions),2);
    summary.UnintendedDeadlockFound=any(dead & ~isTerminal);
    summary.StructuralDeadMarkings=nnz(~any(r.enabled,2));
    canFinish=isTerminal;
    while true
        previous=canFinish;
        canFinish(r.edges(canFinish(r.edges(:,2)),1))=true;
        if isequal(previous,canFinish), break; end
    end
    summary.AllStatesCanReachVehicleCompletion=all(canFinish);
    summary.CoverabilityStatus="Exact finite reachability set; coverable iff dominated by a listed marking; no omega needed";
end
out=options.output_directory; if ~exist(out,'dir'), mkdir(out); end
placeTable=table(p,m0,terminal,bounds,max(r.markings,[],1)', ...
    'VariableNames',{'Place','InitialTokens','VehicleTerminalTokens','InvariantBound','ObservedReachabilityMaximum'});
writetable(placeTable,fullfile(out,'places.csv'));
writetable(table(t,'VariableNames',{'Transition'}),fullfile(out,'transitions.csv'));
writetable(arcs,fullfile(out,'arcs.csv'));
write_matrix(Pre,p,t,out,'pre_matrix.csv'); write_matrix(Post,p,t,out,'post_matrix.csv');
write_matrix(C,p,t,out,'incidence_matrix.csv');
write_matrix(Y,p,"Invariant"+(1:size(Y,2)),out,'p_invariants.csv');
writetable(array2table(r.markings,'VariableNames',cellstr(p)),fullfile(out,'reachable_markings.csv'));
writetable(array2table(r.edges,'VariableNames',{'SourceState','DestinationState','TransitionIndex'}),fullfile(out,'reachability_edges.csv'));
notes=["Scope: six-vehicle deterministic initial marking; untimed atomic P/T firings, guards ignored.";
    "pToArrive + pWait + pChargeNormal + pChargeMedium + pChargeFast + pDone = N.";
    "Each pAvailTYPE + pChargeTYPE equals its initial charger count; pArrivalReady and pDispatch each remain 1.";
    "These nonnegative conservation laws bound every place for any fixed finite N, not uniformly across arbitrary workload sizes.";
    "pDone can reach N=6, so bounded does not mean 1-safe.";
    "Vehicle completion marking has all N vehicles in pDone, empty pending/waiting/charging places and all resources returned.";
    "tRecharge remains enabled structurally at completion (and earlier): the full unguarded net has no dead marking.";
    "Removing only tRecharge for the deadlock diagnostic makes vehicle completion an intended dead marking.";
    "Strict liveness is false: after completion tArrival and all charging transitions can never fire again.";
    "Existence of a completion path is not guaranteed progress for all schedules: the unguarded recharge self-loop can repeat forever.";
    "The real tRecharge_pre guard permits recharge only after EV completion and only if energy is missing; COMMON_POST then stops.";
    "FIFO identity, types, energy, preference, grid/battery reservations, kWh, timers and STOP_SIMULATION are external MATLAB state.";
    "Structural absence of unintended vehicle deadlocks does NOT prove deadlock freedom of the guarded implementation.";
    "Invariants refer to atomic markings. During GPenSIM timed firing, tokens in flight must be included; PN.X alone may temporarily omit them.";
    "Cutoff results are partial: NaN means not established, and observed maxima are not upper bounds unless exploration is complete.";
    "Initial marking names/values mirror src/ev_simulate_scenario.m; structural arcs and matrices are read directly from ev_basic_pdf()."];
lines=string(evalc('disp(summary)'))+newline+join(notes,newline)+newline;
for j=1:size(Y,2)
    parts=string(Y(Y(:,j)>0,j))+"*"+p(Y(:,j)>0);
    lines=lines+"Invariant "+j+": "+join(parts," + ")+" = "+constants(j)+newline;
end
write_text(fullfile(out,'structural_summary.txt'),lines);
write_text(fullfile(out,'coverability_summary.txt'),summary.CoverabilityStatus+newline+ ...
    "Scope: pure token markings only. Complete="+r.complete+"; states="+size(r.markings,1)+newline);
result=struct('summary',summary,'Pre',Pre,'Post',Post,'C',C,'places',placeTable, ...
    'transitions',t,'arcs',arcs,'invariants',Y,'invariantConstants',constants,'reachability',r,'notes',notes);
save(fullfile(out,'petri_analysis.mat'),'result');
disp(summary); fprintf('Structural outputs saved in %s\n',out);
end

function [Y,tree]=toolkit_analysis(Pre,Post,p,t,m0,limit)
% Separate non-nested cleanup restores globals even if the toolbox fails.
global PN;
oldPN=PN; cleanup=onCleanup(@() restore_pn(oldPN));
PN=struct('incidence_matrix',[Pre' Post'],'No_of_places',numel(p), ...
    'No_of_transitions',numel(t),'X',m0','Inhibitors_exist',false, ...
    'global_places',struct('name',cellstr(p)), 'global_transitions',struct('name',cellstr(t)), ...
    'Set_of_Firing_Times',ones(1,numel(t)), ...
    'Set_of_Firing_Costs_Fixed',zeros(1,numel(t)), ...
    'Set_of_Firing_Costs_Variable',zeros(1,numel(t)));
% Unit times are dummy tree labels; no timing interpretation is made.
evalc('rows=pinvariant(PN);'); Y=rows';
evalc('tree=retree(PN,limit);');
end
function restore_pn(value)
global PN; PN=value;
end
function write_matrix(A,p,t,out,name)
tab=array2table(A,'VariableNames',cellstr(t));
tab=addvars(tab,p,'Before',1,'NewVariableNames','Place'); writetable(tab,fullfile(out,name));
end
function write_text(path,value)
fid=fopen(path,'w'); assert(fid>=0); cleanup=onCleanup(@() fclose(fid)); fprintf(fid,'%s',value);
end
