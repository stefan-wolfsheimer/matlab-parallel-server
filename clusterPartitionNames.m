function pn = clusterPartitionNames(cluster)
% Return cluster partition names

% Copyright 2023 The MathWorks, Inc.

narginchk(1,1)

if ~isa(cluster,'parallel.cluster.Generic')
    error('Must provide a cluster object.')
end

% The plugin scripts are not on the path (needed for
% runSchedulerCommand).  Need to change directories to it first.
% Tried calling feval instead, but
% feval(/very/long/path/to/plugin/scripts/fcn) won't work.
odir = cd(fullfile(cluster.PluginScriptsLocation,"private"));
% Change back to the old directory on cleanup
x = onCleanup(@()cd(odir));

commandToRun = "sinfo -o %R --noheader | sort";
[FAILED, pn] = runSchedulerCommand(cluster, commandToRun);
pn = strtrim(pn);
if FAILED~=false
    error("Failed to get partitions: " + pn)
end

pn = strsplit(pn)';

end
