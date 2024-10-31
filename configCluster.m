function configCluster
% Configure MATLAB to submit to the cluster.

% Copyright 2013-2023 The MathWorks, Inc.

% Cluster list
cluster_dir = fullfile(fileparts(mfilename('fullpath')),'IntegrationScripts');
% Listing of setting file(s).  Derive the specific one to use.
cluster_list = dir(cluster_dir);
% Ignore . and .. directories
cluster_list = cluster_list(arrayfun(@(x) x.name(1), cluster_list) ~= '.');
len = length(cluster_list);
if len==0
    error('No cluster directory exists.')
elseif len==1
    cluster = cluster_list.name;
else
    cluster = lExtractPfile(cluster_list);
end

% Import cluster definitions
def = clusterDefinition(cluster);

% Determine the name of the cluster profile
if isfield(def,'Name')
    profile = def.Name;
else
    profile = cluster;
end

% Delete the profile (if it exists)
% In order to delete the profile, check first if an existing profile.  If
% so, check if it's the default profile.  If so, set the default profile to
% "local" (otherwise, MATLAB will throw the following warning)
%
%  Warning: The value of DefaultProfile is 'name-of-profile-we-want-to-delete'
%           which is not the name of an existing profile.  Setting the
%           DefaultProfile to 'local' at the user level.  Valid profile
%           names are:
%           'local' 'profile1' 'profile2' ...
%
% This way, we bypass the warning message.  Then remove the old incarnation
% of the profile (that we're going to eventually create.)
if verLessThan('matlab','9.13')
    % R2022a and older
    % Handle to function returning list of cluster profiles
    cp_fh = @parallel.clusterProfiles;
    % Handle to function returning default cluster profile
    dp_fh = @parallel.defaultClusterProfile;
else
    % R2022b and newer
    % Handle to function returning list of cluster profiles
    cp_fh = @parallel.listProfiles;
    % Handle to function returning default cluster profile
    dp_fh = @parallel.defaultProfile;
end
if any(strcmp(profile,feval(cp_fh))) %#ok<*FVAL>
    % The profile exists.  Check if it's the default profile.
    if strcmp(profile,feval(dp_fh))
        % The profile is the default profile.  Change the default profile
        % to the default profile (local or Processes) to avoid the
        % afformentioned warning.

        % Get the list of factory profile names
        %
        %  Before R2022b: local
        %  After  R2022a: Processes, Threads
        %
        % In either case, pick the first one
        fpn = parallel.internal.settings.getFactoryProfileNames;
        dp_fh(fpn{1});
    end
    % The profile is not the default profile, safely remove it.
    parallel.internal.ui.MatlabProfileManager.removeProfile(profile)
end

% Checks to see if ClusterHost is set to determine job submission type.
if isfield(def, 'AdditionalProperties') && ...
        isfield(def.AdditionalProperties, 'ClusterHost') && ...
        strlength(def.AdditionalProperties.ClusterHost)>0
    CLUSTER_HOST_SET = true;
else
    CLUSTER_HOST_SET = false;
end

% Checks to see if HasSharedFileSystem is set to true or false
if isfield(def, 'HasSharedFilesystem') && ...
        ~isempty(def.HasSharedFilesystem) && def.HasSharedFilesystem
    HAS_SHARED_FILESYSTEM = true;
else
    HAS_SHARED_FILESYSTEM = false;
end

% Checks to see if 'PromptForUsername' is set to determine if the user needs to be prompted for their username on 'remote' configurations.
% PC clients will always be prompted.  Unix clients should only be prompted when off-cluster, as on-cluster configurations
% will use the 'USER' environment variable. 
if isfield(def, 'PromptForUsername') && ...
        ~isempty(def.PromptForUsername) && def.PromptForUsername
    PROMPT_FOR_USERNAME = true;
else
    PROMPT_FOR_USERNAME = false;
end

% Construct the user's Job Storage Location folder
if CLUSTER_HOST_SET && HAS_SHARED_FILESYSTEM
    if ispc
        user = lGetRemoteUsername(cluster);
        if ~isfield(def, 'JobStorageLocation') || ~isfield(def.JobStorageLocation, 'windows') || ...
                strlength(def.JobStorageLocation.windows)==0
            error(['JobStorageLocation.windows field must exist and not be empty in the configuration file.' ...
                10 'Specify the UNC Path that the MATLAB client has access to on the cluster.'])
        elseif ~isfield(def, 'JobStorageLocation') || ~isfield(def.JobStorageLocation, 'unix') || ...
                strlength(def.JobStorageLocation.unix)==0
            error(['JobStorageLocation.unix field must exist and not be empty in the configuration file.' ...
                10 'Specify the path that the MATLAB client has access to on the cluster.'])
        else
            jsl = def.JobStorageLocation.windows;
            rjsl = def.JobStorageLocation.unix;
        end
    else
        if PROMPT_FOR_USERNAME
            user = lGetRemoteUsername(cluster);
        else
            user = getenv('USER');
        end
        if ~isfield(def, 'JobStorageLocation') || ~isfield(def.JobStorageLocation, 'unix') || ...
                strlength(def.JobStorageLocation.unix)==0
            error(['JobStorageLocation.unix field must exist and not be empty in the configuration file.' ...
                10 'Specify the path that the MATLAB client has access to on the cluster.'])
        else
            jsl = def.JobStorageLocation.unix;
            rjsl = '';
        end
    end
    % Modify the JobStorageLocation with the user-specified username if necessary
    if PROMPT_FOR_USERNAME
        if ~isempty(jsl)
            % Gather the username environment variable
            if ispc
                envusr = getenv('USERNAME');
            else
                envusr = getenv('USER');
            end
            % Replace the username environment variable with the user-specified value
            if contains(jsl,envusr)
                jsl = replace(jsl, envusr, user);
            else
                error(['Error configuring JobStorageLocation.\n' ...
                    'Unable to replace local username "%s" with supplied username "%s".'], envusr, user);
            end
        end
    end
elseif CLUSTER_HOST_SET
    user = lGetRemoteUsername(cluster);
    jsl = def.JobStorageLocation;
    rjsl = def.AdditionalProperties.RemoteJobStorageLocation;
else
    user = '';
    jsl = def.JobStorageLocation;
    rjsl = '';
end

% Create the Job Storage Location if it doesn't already exist
if exist(jsl,'dir')==false
    [status, err, eid] = mkdir(jsl);
    if status==false
        error(eid,'Failed to create directory %s: %s', jsl, err)
    end
end

% Modify the rjsl with the user-specified username
if ~isempty(rjsl)
    % Gather the username environment variable
    if ispc
        envusr = getenv('USERNAME');
    else
        envusr = getenv('USER');
    end
    % Replace the username environment variable with the user-specified
    % value.
    if contains(rjsl,envusr)
        rjsl = replace(rjsl, envusr, user);
    else
        error(['Error configuring RemoteJobStorageLocation.\n' ...
            'Unable to replace local username "%s" with supplied username "%s".'], envuser, user);
    end
end

% Assemble the cluster profile with the information collected
assembleClusterProfile(jsl, rjsl, cluster, user, profile, def, CLUSTER_HOST_SET, HAS_SHARED_FILESYSTEM);

fprintf('Complete.  Default cluster profile set to "%s".\n', profile)

end


function cluster_name = lExtractPfile(cl)
% Display profile listing to user to select from

len = length(cl);
for pidx = 1:len
    name = cl(pidx).name;
    names{pidx,1} = name; %#ok<AGROW>
end

selected = false;
while selected==false
    for pidx = 1:len
        fprintf('\t[%d] %s\n',pidx,names{pidx});
    end
    idx = input(sprintf('Select a cluster [1-%d]: ',len));
    selected = idx>=1 && idx<=len;
end
cluster_name = cl(idx).name;

end


function un = lGetRemoteUsername(cluster)

un = input(['Username on ' upper(cluster) ' (e.g. jdoe): '],'s');
if isempty(un)
    error(['Failed to configure cluster: ' cluster])
end

end


function assembleClusterProfile(jsl, rjsl, cluster, user, profile, def, CLUSTER_HOST_SET, HAS_SHARED_FILESYSTEM)

% Create generic cluster profile
c = parallel.cluster.Generic;

% Required mutual fields
% Location of the Integration Scripts
c.IntegrationScriptsLocation = fullfile(fileparts(mfilename('fullpath')),'IntegrationScripts', cluster);
c.NumWorkers = def.NumWorkers;
c.OperatingSystem = 'unix';

% Import list of AdditionalProperties from the config file
% CAUTION: Will overwrite any duplicate fields already set in this file
if isfield(def, 'AdditionalProperties')
    configProps = fieldnames(def.AdditionalProperties);
    for i = 1:length(configProps)
        c.AdditionalProperties.(configProps{i}) = def.AdditionalProperties.(configProps{i});
    end
end

c.HasSharedFilesystem = def.HasSharedFilesystem;

if CLUSTER_HOST_SET
    c.AdditionalProperties.Username = user;
    if isfield(def, 'ClusterMatlabRoot') && ~isempty(def.ClusterMatlabRoot)
        c.ClusterMatlabRoot = def.ClusterMatlabRoot;
    end
    if HAS_SHARED_FILESYSTEM
        if ispc
            jsl = struct('windows',jsl,'unix',rjsl);
            if isprop(c.AdditionalProperties, 'RemoteJobStorageLocation')
                c.AdditionalProperties.RemoteJobStorageLocation = '';
            end
        end
    else
        c.AdditionalProperties.RemoteJobStorageLocation = rjsl;
    end
end
c.JobStorageLocation = jsl;

% Save Profile
c.saveAsProfile(profile);
c.saveProfile('Description', profile)

% Set as default profile
parallel.defaultClusterProfile(profile);

end
