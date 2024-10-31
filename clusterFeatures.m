function [uniq_feats, combo_feats] = clusterFeatures(arg1, arg2)
% Return features/constraints for Slurm scheduler

% Copyright 2023 The MathWorks, Inc.

narginchk(0,2)

cluster = [];
part = '';

if nargin==1
    if isa(arg1,'parallel.cluster.Generic')
        % Running on the desktop
        % Argument passed in is the cluster object
        cluster = arg1;
    else
        % Running on the cluster
        % Argument passed in is the name of the partition
        part = arg1;
    end
else
    if isa(arg1,'parallel.cluster.Generic')
        % Running on the desktop
        % First argument passed in is cluster object, second argument is
        % partition
        cluster = arg1;
        part = arg2;
    else
        % Passed in two i/p args, but first wasn't cluster object
        error('Cluster object must provide as the first argument.')
    end
end

% The plugin scripts are not on the path (needed for
% runSchedulerCommand).  Need to change directories to it first.
% Tried calling feval instead, but
% feval(/very/long/path/to/plugin/scripts/fcn) won't work.
odir = cd(fullfile(cluster.PluginScriptsLocation,"private"));
% Change back to the old directory on cleanup
x = onCleanup(@()cd(odir));

% Add partition (if provided)
if ~isempty(part)
    part = "-p " + part;
end

% Get list of unique features (based on the partition, if supplied)
commandToRun = sprintf("sinfo %s -O Features:60 | tail -n +2 | tr ',' '\\n' | tr -d ' ' | sort -u", part);
[FAILED, uniq_feats] = runSchedulerCommand(cluster, commandToRun);
uniq_feats = strtrim(uniq_feats);
if FAILED~=false
    error("Failed to get features: " + uniq_feats)
end
uniq_feats = strsplit(uniq_feats)';

% Get list of features that can work together.  For example, if a user
% requests an "EPYC", it wouldn't also make sense to request "E5-2640".
commandToRun = sprintf("sinfo %s -O Features:60 | tail -n +2 | tr -d ' ' | sort -u", part);
[FAILED, combo_feats] = runSchedulerCommand(cluster, commandToRun);
combo_feats = strtrim(combo_feats);
if FAILED~=false
    error("Failed to get features: " + combo_feats)
end
combo_feats = strsplit(combo_feats)';

end
