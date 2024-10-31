function reason = willRun(job)
% Determine when the job will run

% Copyright 2023 The MathWorks, Inc.

narginchk(1,1)

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
INVALID_JOB_ID = "Invalid job id specified";

% MW: What if there are more than one sched ID?
commandToRun = sprintf('squeue -j %s -O Reason:100',jobID{1});
[FAILED, result] = runSchedulerCommand(cluster, commandToRun);
result = strtrim(result);
if FAILED~=false && ~contains(result,INVALID_JOB_ID)
    error("Failed to get status of job: " + result)
end

% Parse the job status
[~, result] = strtok(result,' ');
result = strtrim(result);
if strcmpi(result,'none')
    % If there's no reason, it's because the job is already running
    reason = 'Running';
elseif isempty(result) || contains(result,INVALID_JOB_ID)
    % If the job can't be found, it's because the job is already finished
    reason = 'Finished';
else
    % The job is queued for some reason
    reason = result;
end

end
