function postConstructFcn(cluster) %#ok<INUSD>
%POSTCONSTRUCTFCN Perform custom configuration after call to PARCLUSTER
%
% POSTCONSTRUCTFCN(CLUSTER) execute code on cluster object CLUSTER.
%
% See also parcluster.

% Copyright 2023-2024 The MathWorks, Inc.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Required Properties Banner %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Uncomment the following code block if you'd like to display a banner informing the user that
% an AdditionalProperties value is required to submit a job.
    
persistent DONE
mlock

if DONE
    % We've already warned to correctly set the AdditionalProperties
    return
else
    % Only want to check once per MATLAB session
    DONE = true;
end

ap = cluster.AdditionalProperties;
profile = split(cluster.Profile);

if isempty(validatedPropValue(ap, 'WallTime', 'char', ''))
    fprintf(['\n\tMust set WallTime before submitting jobs to %s.  E.g.\n\n', ...
             '\t>> c = parcluster;\n', ...
             '\t>> %% 5 hour, 30 minute walltime\n', ...
             '\t>> c.AdditionalProperties.WallTime = ''05:30:00'';\n', ...
             '\t>> c.saveProfile\n'], profile{1})
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Non-Standard RemoteJobStorageLocation %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Uncomment the following code block if the cluster has a non-standard RJSL that requires user input rather 
% than relying on the same pattern for all users.
% You MUST also make corresponding changes to the cluster.conf file(s).

% Step One -- Modify .conf file(s) with "default_proj_name" where the custom value should go.
% Example hpcDesktop.conf file:

% # Remote Job Storage Location
% # Directory on the cluster's file system to be used as the remote job storage location.   
% RemoteJobStorageLocation (Windows) = /proj/default_proj_name/"$USERNAME"/.matlab/generic_cluster_jobs/HPC/"$COMPUTERNAME"
% RemoteJobStorageLocation (Unix) = /proj/default_proj_name/"$USER"/.matlab/generic_cluster_jobs/HPC/"$HOST"

% Step Two - Uncomment the following code block and modify as necessary

%{
if contains(cluster.AdditionalProperties.RemoteJobStorageLocation, 'default_proj_name')
    projectname = lGetProjectName;
    cluster.AdditionalProperties.RemoteJobStorageLocation = replace(cluster.AdditionalProperties.RemoteJobStorageLocation, 'default_proj_name', projectname);
    if ~contains(cluster.AdditionalProperties.RemoteJobStorageLocation, projectname)
        error(['Failed to configure RemoteJobStorageLocation with project name "%s".' ...
            '\nManually verify that a correct RemoteJobStorageLocation value is configured.'], projectname)
    end
    cluster.saveProfile
end


function pn = lGetProjectName

pn = input('Project name (e.g. fs#####): ','s');
if isempty(pn)
    error('Failed to configure cluster.')
end
end
%}


end
