function result = seff(job,debug)
% Provides statistics related to the efficiency of resource usage by the completed job.

% Copyright 2024 The MathWorks, Inc.

narginchk(1,2)
if nargin==1
    debug = false;
end

if ~isa(job,'parallel.job.CJSIndependentJob') ...
        && ~isa(job,'parallel.job.CJSCommunicatingJob')
    error('Must provide an Independent or Communicating Job')
end

cluster = job.Parent;

% The plugin scripts are not on the path (needed for
% runSchedulerCommand).  Need to change directories to it first.
% Tried calling feval instead, but
% feval(/very/long/path/to/plugin/scripts/fcn) won't work.
odir = cd(fullfile(cluster.PluginScriptsLocation,"private"));
% Change back to the old directory on cleanup
x = onCleanup(@()cd(odir));

jobID = job.getTaskSchedulerIDs();
INVALID_JOB_ID = "Job not found.";

% MW: What if there are more than one sched ID?
if debug
    flag = "-d ";
else
    flag = "";
end
commandToRun = sprintf('seff %s %s',flag,jobID{1});
[FAILED, result] = runSchedulerCommand(cluster, commandToRun);
result = strtrim(result);
if FAILED~=false && ~contains(result,INVALID_JOB_ID)
    error("Failed to get status of job: " + result)
end

% Parse the job status
[~, result] = strtok(result,' ');
result = strtrim(result);

end
