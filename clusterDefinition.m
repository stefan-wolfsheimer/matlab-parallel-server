function out = clusterDefinition(cluster)
% This function will be used to read in the clusternameDesktop.conf or clusternameCluster.conf and to extract
% the necessary information in order to build the cluster profile
% in MATLAB.  clusterDefinition will pass back a structure to
% configCluster.

% Copyright 2017-2023 The MathWorks, Inc.

% Determine the location of the clusternameDesktop.conf or clusternameCluster.conf; we assume that
% it is in the same directory as configCluster. Additional logic to support in-place development. 
filenameCluster = fullfile(fileparts(mfilename('fullpath')), sprintf('%sCluster.conf',cluster));
filenameRemoteCluster = fullfile(fileparts(mfilename('fullpath')), sprintf('%sRemoteCluster.conf',cluster));
filenameDesktop = fullfile(fileparts(mfilename('fullpath')), sprintf('%sDesktop.conf',cluster));
filenameRemoteDesktop = fullfile(fileparts(mfilename('fullpath')), sprintf('%sRemoteDesktop.conf',cluster));
if (exist(filenameDesktop, 'file') || exist(filenameRemoteDesktop, 'file')) && ...
        (exist(filenameCluster, 'file') || exist(filenameRemoteCluster, 'file'))
    validYesNoResponse = {'y', 'n', ''};
    confMessage = 'Is this configuration for on-cluster use? [Y/n] ';
    confResponse = iLoopUntilValidStringInput(confMessage, validYesNoResponse);
    if strcmpi(confResponse, 'y') || isempty(confResponse)
        if exist(filenameCluster, 'file')
            file = fullfile(fileparts(mfilename('fullpath')), sprintf('%sCluster.conf',cluster));
            fprintf('Using file %sCluster.conf\n',cluster)
        else
            file = fullfile(fileparts(mfilename('fullpath')), sprintf('%sRemoteCluster.conf',cluster));
            fprintf('Using file %sRemoteCluster.conf\n',cluster)
        end
    else
        if exist(filenameDesktop, 'file') 
            file = fullfile(fileparts(mfilename('fullpath')), sprintf('%sDesktop.conf',cluster));
            fprintf('Using file %sDesktop.conf\n',cluster)
        else
            file = fullfile(fileparts(mfilename('fullpath')), sprintf('%sRemoteDesktop.conf',cluster));
            fprintf('Using file %sRemoteDesktop.conf\n',cluster)
        end
    end
elseif exist(filenameDesktop, 'file')
    file = fullfile(fileparts(mfilename('fullpath')), sprintf('%sDesktop.conf',cluster));
elseif exist(filenameCluster, 'file')
    file = fullfile(fileparts(mfilename('fullpath')), sprintf('%sCluster.conf',cluster));
elseif exist(filenameRemoteDesktop, 'file')
    file = fullfile(fileparts(mfilename('fullpath')), sprintf('%sRemoteDesktop.conf',cluster));
elseif exist(filenameRemoteCluster, 'file')
    file = fullfile(fileparts(mfilename('fullpath')), sprintf('%sRemoteCluster.conf',cluster));
else
    error('Unable to find matching .conf file for cluster "%s".', cluster)
end

[~, name, ext] = fileparts(file);
configFileName = strcat(name,ext);
 
% Import cluster definitions
if verLessThan('matlab','9.14')
    out = iBackwardsCompatibleClusterDef(file);
else
    out = parallel.internal.discover.FilesystemGeneric.parseTemplateFile(file);
end

if isempty(out)
    error('Error in reading %s.  Please make sure file is filled out correctly.', configFileName);
end

% Clean up  
out = iCleanUp(out);

% Error Check 
out = iErrorCheckDef(out);

function out = iBackwardsCompatibleClusterDef(file)

% If cluster.conf does not exist or can't be accessed, throw an error
if file < 0
    error('Unable to read or access %s\n%s', configFileName, errormsg)
end

out = [];

% Read file
lines = iLoadFile(file);

% Construct mapping of environment variable tokens (i.e. "$VARIABLE") to value
[envVarTokens, envVarValues] = iResolveEnvVarTokens(lines);

% Parse each line
profileData = struct();
heading = string.empty;
for idx = 1:numel(lines)
    line = lines(idx);

    % Heading directive
    if startsWith(line, "[") && endsWith(line, "]")
        % Split by dot: "[ ABC.XYZ ]" -> ["ABC", "XYZ"]
        heading = split(strtrim(extractBetween(line, "[", "]")), ".");

        invalidHeadingParts = iGetInvalidVarNames(heading);
        if ~isempty(invalidHeadingParts)
            dctSchedulerMessage(2, "Skipping file '%s' because the following line defines the invalid variable name '%s':\n%s", ...
                file, invalidHeadingParts(1), line);
            return
        end
        continue
    end

    % Give up if there isn't an equals sign
    if ~contains(line, "=")
        dctSchedulerMessage(2, "Skipping file '%s' because the following line could not be interpreted:\n%s", ...
            file, line);
        return
    end

    % Get field name and attributes, expecting line of form:
    % name (attributes) = value
    [name, attributes, value] = iParseLine(line);
    invalidNameParts = iGetInvalidVarNames(name);
    if ~isempty(invalidNameParts)
        dctSchedulerMessage(2, "Skipping file '%s' because the following line defines the invalid variable name '%s':\n%s", ...
            file, invalidNameParts(1), line);
        return
    end

    % Ignore OS-specific lines that aren't for this OS
    if iHasAnyOSAttribute(attributes) && ~iHasThisOSAttribute(attributes)
        continue
    end

    % Get full name including prepended heading
    fullname = [heading; name];

    % Resolve environment variables
    value = replace(value, envVarTokens, envVarValues);

    % Try to convert value to a double or logical
    value = iAttemptConversion(value);

    % Add PV pair to struct
    profileData = setfield(profileData, fullname{:}, value);
end

out = profileData;

% Function iBackwardsCompatibleClusterDef end
end

function out = iCleanUp(out)
% Change fields in 'out' to a char
fields = fieldnames(out);
for i = 1:numel(fields)
    if isstring(out.(fields{i}))
        out.(fields{i}) = char(out.(fields{i}));
    end
end

% Change out.AdditionalProperties fields to a char
propfields = fieldnames(out.AdditionalProperties);
for i = 1:numel(propfields)
    if isstring(out.AdditionalProperties.(propfields{i}))
        out.AdditionalProperties.(propfields{i}) = char(out.AdditionalProperties.(propfields{i}));
    end
end


% Function iCleanUp end
end

function out = iErrorCheckDef(out)
% Error checking and character checks

% Verify that numWorkers is specified and an integer
numWorkersStr = string(out.NumWorkers);
if (strlength(numWorkersStr) == 0)
    error('NumWorkers must be specified in the %s configuration file.', configFileName)
elseif ~isa(out.NumWorkers, 'double')
    error('NumWorkers must be specified as an integer in the %s configuration file.', configFileName)
end

% Changes ClusterHost value to a char
if isfield(out, 'AdditionalProperties') && isfield(out.AdditionalProperties, 'ClusterHost')
    out.AdditionalProperties.ClusterHost = char(out.AdditionalProperties.ClusterHost);
end

% Perform last character check for RemoteJobStorageLocation
% If cluster is running Windows OS, change the second argument to 'pc' from 'unix'
if isfield(out, 'RemoteJobStorageLocation') && (strlength(out.RemoteJobStorageLocation) > 0)
    out.RemoteJobStorageLocation = lastCharacterCheck(out.RemoteJobStorageLocation, 'unix');
end

% Change JSL stuct values to a char
if isfield(out, 'JobStorageLocation')
    if isfield(out.JobStorageLocation, 'unix')
        out.JobStorageLocation.unix = char(out.JobStorageLocation.unix);
    elseif isfield(out.JobStorageLocation, 'windows')
        out.JobStorageLocation.windows = char(out.JobStorageLocation.windows);
    end
end

% Function iErrorCheckDef end
end

function out = lastCharacterCheck(in, machineType)

% Verify that the last string is '/' or '\' and if not, append it

% Set a default in case no modifications are required
out = in;

% Return if out is empty to support remote submission on-cluster
%if isempty(out)
if (strlength(out) == 0)
    return
end

% Check to see if we need to append a slash as a last character
if strcmp(machineType, 'pc')
    if ~strcmp(in(end), '\')
        out = strcat(in, '\');
    end
else
    if ~strcmp(in(end), '/')
        out = strcat(in, '/');
    end
end
% Function lastCharacterCheck end
end

function lines = iLoadFile(file)
lines = splitlines(string(fileread(file)));
lines = strtrim(lines); % strip whitespace
lines = lines(lines ~= ""); % remove empties
lines = lines(~startsWith(lines, "#")); % remove comments
% Function iLoadFile end
end

function [envVarTokens, envVarValues] = iResolveEnvVarTokens(lines)
% This is looking for everything between $ and " EXCEPT for =.  
% Define the pattern for extracting environment variables and replace the use of the "cellfun" function with a loop
envVarPattern = '"\$\w+"';
envVarTokens = cell(size(lines));
for i = 1:numel(lines)
    envVarTokens{i} = regexp(lines{i}, envVarPattern, 'match');
end
envVarTokens = unique([envVarTokens{:}]);
envVarNames = extractBetween(envVarTokens, '"$', '"');
envVarValues = cellfun(@getenv, envVarNames, 'UniformOutput', false);

% Set MATLAB_VERSION_STRING if it is used but unset
verIdx = find(envVarNames == "MATLAB_VERSION_STRING");
if ~isempty(verIdx) && isempty(envVarValues{verIdx})
    envVarValues{verIdx} = version('-release');
end

% Change to string
envVarTokens = string(envVarTokens);
envVarValues = string(envVarValues);
% Function iResolveEnvVarTokens end
end

function [name, attributes, value] = iParseLine(line)

% Get field name, attributes and value, expecting line of form:
% name (attributes) = value
% or
% (attributes) name = value
% Implementation exploits the restriction that neither name nor attributes may
% contain an equals sign.

% Extract value
value = strtrim(extractAfter(line, "="));

% Extract "name (attributes)" or "(attributes) name"
nameAndAttrs = strtrim(extractBefore(line, "="));

% Extract and parse attribute specifier
attributeSpecifier = extractBetween(nameAndAttrs,'(',')','Boundaries','inclusive');
attributes = iParseAttributes(extractBetween(attributeSpecifier, "(", ")"));

% Extract and parse name
name = strtrim(erase(nameAndAttrs, attributeSpecifier));
name = split(name, ".");
% Function iParseLine end
end

function value = iAttemptConversion(value)
% Convert value to a double or logical if possible, otherwise leave as string
valueAsDouble = str2double(value);
if ~isnan(valueAsDouble)
    value = valueAsDouble;
elseif strcmpi(value, "true")
    value = true;
elseif strcmpi(value, "false")
    value = false;
elseif iCouldBeTextVector(value)
    % Evaluate expression with no allowed functions to parse the string
    value = eval(value);
end
% Function iAttemptConversion end
end

function tf = iCouldBeTextVector(str)
tf = iCouldBeStringArray(str) || iCouldBeCellStr(str);
end

function tf = iCouldBeStringArray(str)
    tf = contains(str, '[') && contains(str, ']') && contains(str, '"');
end

function tf = iCouldBeCellStr(str)
    tf = contains(str, '{') && contains(str, '}') && contains(str, "'");
end

function invalidVarNames = iGetInvalidVarNames(names)
% For the provided names, return any which are not valid MATLAB variable names
isValidName = arrayfun(@isvarname, names);
invalidVarNames = names(~isValidName);
end

function attributes = iParseAttributes(attributeString)
% Expecting string like: attr1, attr2
% Returns a string array of the attributes
attributes = strtrim(split(attributeString, ","));
end

function tf = iHasAttributes(attributesToCheck, attributeList)
% Do the attributesToCheck appear in attributeList?
% Returns a logical array of the same size as attributesToCheck.
hasAttribute = @(attr) any(strcmpi(attr, attributeList));
tf = arrayfun(hasAttribute, attributesToCheck);
end

function tf = iHasAnyAttributes(attributesToCheck, attributeList)
% Do any of the attributesToCheck appear in attributeList?
tf = any(iHasAttributes(attributesToCheck, attributeList));
end

function tf = iHasAnyOSAttribute(attributeList)
% Do any of the OS-specific attributes appear in attributeList?
allOSNames = ["WINDOWS", "UNIX", "MAC", "LINUX"];
tf = iHasAnyAttributes(allOSNames, attributeList);
end

function tf = iHasThisOSAttribute(attributeList)
% Do any of the OS-specific attributes for this OS appear in attributeList?
if ispc
    thisOSNames = "WINDOWS";
elseif ismac
    thisOSNames = ["UNIX", "MAC"];
else
    thisOSNames = ["UNIX", "LINUX"];
end
tf = iHasAnyAttributes(thisOSNames, attributeList);
% Function iHasThisOSAttribute end
end


function returnValue = iLoopUntilValidStringInput(message, validValues)
% Function to loop until a valid response is obtained user input
returnValue = 'null';

while ~any(strcmpi(returnValue, validValues))
    returnValue = input(message, 's');
end
% Function iLoopUntilValidStringInput end
end

% clusterDefinition end
end
