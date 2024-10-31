function gcards = clusterGpuCards(arg1, arg2)
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
% Saw a case where the same GPU card was listed twice (with different parameters), so
% we should also uniqify the list.
commandToRun = sprintf("sinfo %s --format=%%G | tail -n +2 | cut -f 2 -d: | sort -u", part);
[FAILED, gcards] = runSchedulerCommand(cluster, commandToRun);
gcards = strtrim(gcards);
if FAILED~=false
    error("Failed to get list of GPU cards: " + gcards)
end
gcards = strsplit(gcards)';

% Saw a case where "(null)" appeared.  Shouldn't have any GPU cards listed with a "(" in it.
pidx = contains(gcards,'(');
gcards(pidx) = [];

end
