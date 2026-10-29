function r = ev_petri_reachability(Pre,Post,m0,maximum_state_count)
% Untimed, atomic P/T firings only: never invokes guards or simulations.
validateattributes(maximum_state_count,{'numeric'},{'scalar','integer','positive','finite'});
assert(isequal(size(Pre),size(Post)) && numel(m0)==size(Pre,1));
assert(all(m0>=0 & m0==fix(m0)));
C=Post-Pre; nT=size(Pre,2);
markings=zeros(maximum_state_count,numel(m0)); markings(1,:)=m0(:)';
seen=containers.Map({sprintf('%d,',m0)},1);
edges=zeros(0,3); enabled=false(maximum_state_count,nT);
count=1; head=1; complete=true;
while head<=count
    m=markings(head,:)'; enabled(head,:)=all(m>=Pre,1);
    for t=find(enabled(head,:))
        next=m+C(:,t); key=sprintf('%d,',next);
        if isKey(seen,key)
            dest=seen(key);
        else
            if count>=maximum_state_count, complete=false; break; end
            count=count+1; dest=count; seen(key)=dest; markings(dest,:)=next';
        end
        edges(end+1,:)=[head dest t]; %#ok<AGROW>
    end
    if ~complete, break; end
    head=head+1;
end
r=struct('markings',markings(1:count,:),'edges',edges, ...
    'enabled',enabled(1:count,:),'complete',complete,'processed_states',head-1);
end
