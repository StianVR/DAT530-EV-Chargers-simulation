function analysis = generate_report_figures(options)
%GENERATE_REPORT_FIGURES Read saved CSVs only. Never runs a simulation.
% Explicit folders prevent silent substitution between experiment sizes.
if nargin<1, options=struct(); end
root=fileparts(fileparts(mfilename('fullpath')));
defaults=struct('battery_directory',fullfile(root,'results','battery_monte_carlo'), ...
    'grid_directory',fullfile(root,'results','grid_sensitivity_1'), ...
    'demand_directory',fullfile(root,'results','demand_sensitivity_1'), ...
    'output_directory',fullfile(root,'results','figures'));
for f=fieldnames(defaults)'
    if ~isfield(options,f{1}), options.(f{1})=defaults.(f{1}); end
end
out=options.output_directory;
if ~exist(out,'dir'), mkdir(out); end
analysis.options=options;
analysis.error_bar_description='Mean across seeds +/- one sample standard deviation; no variability estimate for one seed.';
analysis.summary_definitions='Equal weight per seed. P95Wait is the mean of within-run vehicle P95 waits, not a pooled percentile. MaxQueue is the mean of run maxima.';
analysis.sources=table();
families={'battery','grid','demand'};
filenames={'battery_monte_carlo_runs.csv','grid_sensitivity_runs.csv','demand_sensitivity_runs.csv'};
for k=1:3
    family=families{k}; path=fullfile(options.([family '_directory']),filenames{k});
    if ~isfile(path)
        fprintf('%s results not found at %s; skipping its figures and summary.\n',family,path);
        analysis.(family)=table();
        analysis.sources=[analysis.sources;table(string(family),string(path),"missing",0,0, ...
            'VariableNames',{'Experiment','SourceCSV','Status','Rows','Seeds'})]; %#ok<AGROW>
        continue;
    end
    raw=readtable(path,'TextType','string');
    summary=ev_report_summary(raw,family);
    analysis.(family)=summary;
    writetable(summary,fullfile(out,[family '_summary.csv']));
    analysis.sources=[analysis.sources;table(string(family),string(path),"loaded",height(raw),summary.Seeds(1), ...
        'VariableNames',{'Experiment','SourceCSV','Status','Rows','Seeds'})]; %#ok<AGROW>
    fprintf('Loaded %s: %d rows, %d seeds per configuration (%s).\n',family,height(raw),summary.Seeds(1),path);
end
if ~isempty(analysis.battery)
    s=analysis.battery;
    f=new_figure(); cleanup=onCleanup(@() close(f));
    ax=axes(f); bar(ax,1:2,s.MeanWait,0.6,'FaceColor','flat');
    ax.Children.CData=[0.15 0.35 0.60;0.80 0.35 0.10]; hold(ax,'on');
    if all(s.Seeds>1), errorbar(ax,1:2,s.MeanWait,s.StdMeanWait,'k.','LineWidth',1.2,'CapSize',10); end
    xticks(ax,[1 2]); xticklabels(ax,{'Battery OFF','Battery ON'});
    ylabel(ax,'Mean vehicle waiting time [min]'); title(ax,'Battery assistance and mean waiting time');
    subtitle(ax,uncertainty_label(s.Seeds(1)));
    format_axes(ax); limits=ylim(ax); ylim(ax,[min(0,limits(1)) max(limits(2),1)]);
    export_figure(f,out,'battery_mean_wait'); clear cleanup;
end
if ~isempty(analysis.grid)
    plot_lines(analysis.grid,'grid','MeanWait','StdMeanWait', ...
        'Mean vehicle waiting time [min]','Grid capacity and mean waiting time',out,'grid_vs_mean_wait',false);
    plot_lines(analysis.grid,'grid','MeanBatteryEnergyUsed','StdBatteryEnergyUsed', ...
        'Mean battery energy used [kWh]','Grid capacity and battery energy use',out,'grid_vs_battery_use',true);
end
if ~isempty(analysis.demand)
    plot_lines(analysis.demand,'demand','MeanWait','StdMeanWait', ...
        'Mean vehicle waiting time [min]','Arrival demand and mean waiting time',out,'demand_vs_mean_wait',false);
    plot_lines(analysis.demand,'demand','P95Wait','StdP95Wait', ...
        'Mean within-run P95 waiting time [min]','Arrival demand and P95 waiting time',out,'demand_vs_p95_wait',false);
end
writetable(analysis.sources,fullfile(out,'analysis_sources.csv'));
save(fullfile(out,'report_analysis.mat'),'analysis');
fprintf('Report outputs saved in %s\n',out);
end

function f=new_figure()
f=figure('Visible','off','Color','w','Units','pixels','Position',[100 100 1000 680]);
end
function label=uncertainty_label(n)
if n>1, label=sprintf('Across-seed mean +/- 1 SD (n = %d); error bars are not confidence intervals',n);
else, label='Single workload (n = 1); between-seed variability not estimated'; end
end
function format_axes(ax)
set(ax,'FontName','Arial','FontSize',12,'LineWidth',1,'Box','off', ...
    'Color','w','XColor',[0.1 0.1 0.1],'YColor',[0.1 0.1 0.1], ...
    'GridColor',[0.3 0.3 0.3]);
ax.Title.Color=[0.1 0.1 0.1]; ax.Subtitle.Color=[0.2 0.2 0.2];
ax.XLabel.Color=[0.1 0.1 0.1]; ax.YLabel.Color=[0.1 0.1 0.1];
grid(ax,'on'); ax.GridAlpha=0.15;
end
function export_figure(f,out,name)
drawnow;
exportgraphics(f,fullfile(out,[name '.png']),'Resolution',300,'BackgroundColor','white');
exportgraphics(f,fullfile(out,[name '.pdf']),'ContentType','vector','BackgroundColor','white');
savefig(f,fullfile(out,[name '.fig']));
end
function plot_lines(s,family,metric,spread,ytext,heading,out,name,batteryOnly)
f=new_figure(); cleanup=onCleanup(@() close(f));
ax=axes(f); hold(ax,'on'); colors=[0.15 0.35 0.60;0.80 0.35 0.10];
states=[false true]; if batteryOnly, states=true; end
styles={'-o','--s'};
for b=states
    part=s(s.BatteryEnabled==b,:);
    if strcmp(family,'grid'), x=part.GridCapacityKW; else, x=(1:height(part))'; end
    if all(part.Seeds>1)
        errorbar(ax,x,part.(metric),part.(spread),styles{double(b)+1},'Color',colors(double(b)+1,:), ...
            'LineWidth',1.6,'MarkerSize',7,'DisplayName',['Battery ' char(part.BatteryState(1))]);
    else
        plot(ax,x,part.(metric),styles{double(b)+1},'Color',colors(double(b)+1,:), ...
            'LineWidth',1.6,'MarkerSize',7,'DisplayName',['Battery ' char(part.BatteryState(1))]);
    end
end
if strcmp(family,'grid')
    xlabel(ax,'Grid capacity [kW]'); xticks(ax,[150 200 250]); xlim(ax,[140 260]);
else
    xlabel(ax,'Demand level (mean interarrival time)'); xticks(ax,1:3);
    xticklabels(ax,{'Low (15 min)','Baseline (10 min)','High (7.5 min)'}); xlim(ax,[0.8 3.2]);
end
ylabel(ax,ytext); title(ax,heading); subtitle(ax,uncertainty_label(s.Seeds(1)));
legend(ax,'Location','best','Color','white','TextColor',[0.1 0.1 0.1], ...
    'EdgeColor',[0.5 0.5 0.5]); format_axes(ax);
limits=ylim(ax); ylim(ax,[min(0,limits(1)) max(limits(2),1)]);
export_figure(f,out,name);
end
