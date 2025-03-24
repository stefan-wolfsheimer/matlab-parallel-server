function fixConnection(cluster, job)
% Reestablish cluster connection and mirror job

% Copyright 2023 The MathWorks, Inc.

narginchk(1,2)

if ~isa(cluster,'parallel.cluster.Generic')
    error('Must provide a cluster object.')
end

REMOTE_SUBMISSION = isprop(cluster, 'AdditionalProperties') && ...
    isprop(cluster.AdditionalProperties, 'ClusterHost');

if ~REMOTE_SUBMISSION
    disp('No connection to fix.')
    return
end

UPDATE_JOB_OBJECT = nargin==2;
if UPDATE_JOB_OBJECT
    if ~isa(job,'parallel.job.CJSIndependentJob') ...
            && ~isa(job,'parallel.job.CJSCommunicatingJob')
        error('Must provide an Independent or Communicating Job')
    end
end

% The plugin scripts are not on the path.  Need to change directories to it
% first.  Tried calling feval instead, but
% feval(/very/long/path/to/plugin/scripts/fcn) won't work.
odir = cd(fullfile(cluster.PluginScriptsLocation,"private"));
% Change back to the old directory on cleanup
x = onCleanup(@()cd(odir));
rc = getRemoteConnection(cluster);
rc.disconnect
rc = getRemoteConnection(cluster);

if UPDATE_JOB_OBJECT
    % Job object supplied, try last mirroring
    rc.doLastMirrorForJob(job)
end

end
