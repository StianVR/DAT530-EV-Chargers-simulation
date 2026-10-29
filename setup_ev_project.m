function projectRoot = setup_ev_project()
%SETUP_EV_PROJECT Add only project code folders to the current MATLAB path.
% Safe to call repeatedly. Does not run simulations or change folders.
projectRoot = fileparts(mfilename('fullpath'));
folders = {'config','src','model',fullfile('model','callbacks'),'experiments','tests','analysis'};
addpath(projectRoot);
for k = 1:numel(folders)
    addpath(fullfile(projectRoot, folders{k}));
end
rehash;
% Keep the user's existing GPenSIM installation/path unchanged.
end
