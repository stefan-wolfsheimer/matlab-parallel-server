function disableArchiving(cluster)
% Modify file archiving to resolve file mirroring issue.
%
% In R2021b, we switched our default ssh libraries.  In doing so, we've
% seen issues with local zip/tar clients, which can throw the following
% error when submitting the job
%
%   Error using parallel.internal.remoteaccess.FileMirror/addToMirror
%   Error accessing local files:
%   Unable to write header for files_to_copy to archive
%
% This has been resolved in R2022b.  To resolve this for R2021b and R2022a,
% we can change the FileArchiveType to "none".  The implications are that
% each individual file will be copied over (rather than archived as one
% single file), degrading the performance.
%
% This needs to be called anytime a new connection has been made.
% Alternatively, we could put this in getRemoteConnection; however, this
% would negatively effect all R2021b and R2022a users unneccarily.

% Copyright 2022 The MathWorks, Inc.

mr = matlabRelease;
release = ["R2021b","R2022a"];
if ~contains(mr.Release,release)
    disp("Fix only applies to: " + join(release))
    return
end

narginchk(1,1)

if ~isa(cluster,'parallel.cluster.Generic')
    error('Must provide a cluster object.')
end

REMOTE_SUBMISSION = isprop(cluster, 'AdditionalProperties') && ...
    isprop(cluster.AdditionalProperties, 'ClusterHost');

if ~REMOTE_SUBMISSION
    disp('No archiving to fix.')
    return
end

% The plugin scripts are not on the path (needed for
% runSchedulerCommand).  Need to change directories to it first.
% Tried calling feval instead, but
% feval(/very/long/path/to/plugin/scripts/fcn) won't work.
odir = cd(fullfile(cluster.PluginScriptsLocation,"private"));
% Change back to the old directory on cleanup
x = onCleanup(@()cd(odir));
rc = getRemoteConnection(cluster);
rc.FileArchiveType = "none";

end
