function commonSubmitArgs = getCommonSubmitArgs(cluster, numWorkers)
% Get any additional submit arguments for the Slurm sbatch command
% that are common to both independent and communicating jobs.

% Copyright 2016-2024 The MathWorks, Inc.

commonSubmitArgs = '';
ap = cluster.AdditionalProperties;

% Number of cores/node
ppn = validatedPropValue(ap, 'ProcsPerNode', 'double', 0);
if ppn>0
    % Don't request more cores/node than workers
    ppn = min(numWorkers*cluster.NumThreads,ppn);
    assert(rem(ppn,cluster.NumThreads)==0, ...
        'ProcsPerNode (%d) must be greater than or equal to and divisible by NumThreads (%d).', ppn, cluster.NumThreads);
    commonSubmitArgs = sprintf('%s --ntasks-per-node=%d',commonSubmitArgs,ppn/cluster.NumThreads);
end
commonSubmitArgs = sprintf('%s --ntasks-per-core=1',commonSubmitArgs);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% CUSTOMIZATION MAY BE REQUIRED %%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% You may wish to support further cluster.AdditionalProperties fields here
% and modify the submission command arguments accordingly.

%% REQUIRED

% Memory required per CPU
emsg = sprintf(['\n\t>> %%%% Must set MemPerCPU. E.g.\n\n', ...
                '\t>> c = parcluster;\n', ...
                '\t>> c.AdditionalProperties.MemPerCPU = ''4gb'';\n', ...
                '\t>> c.saveProfile\n\n']);
commonSubmitArgs = iAppendRequiredArgument(commonSubmitArgs, ap, ...
    'MemPerCPU', 'char', '--mem-per-cpu=%s', emsg);

% Wall time
emsg = sprintf(['\n\t>> %%%% Must set WallTime. E.g.\n\n', ...
                '\t>> c = parcluster;\n', ...
                '\t>> %%%% 5 hour, 30 minute walltime\n', ...
                '\t>> c.AdditionalProperties.WallTime = ''05:30:00'';\n', ...
                '\t>> c.saveProfile\n\n']);
commonSubmitArgs = iAppendRequiredArgument(commonSubmitArgs, ap, ...
    'WallTime', 'char', '-t %s', emsg);

%% OPTIONAL

% Account name
commonSubmitArgs = iAppendArgument(commonSubmitArgs, ap, ...
    'AccountName', 'char', '-A %s');

% Constraint
commonSubmitArgs = iAppendArgument(commonSubmitArgs, ap, ...
    'Constraint', 'char', '-C %s');

% GPU
ngpus = validatedPropValue(ap, 'GPUsPerNode', 'double', 0);
if ngpus>0
    gcard = validatedPropValue(ap, 'GPUCard', 'char', '');
%    commonSubmitArgs = sprintf('%s --gres=gpu:%s:%d', commonSubmitArgs, gcard, ngpus);
    commonSubmitArgs = sprintf('%s --gpus %d', commonSubmitArgs, ngpus);
 %   commonSubmitArgs = strrep(commonSubmitArgs,'::',':');
end

% Partition (queue)
commonSubmitArgs = iAppendArgument(commonSubmitArgs, ap, ...
    'Partition', 'char', '-p %s');

% Require exclusive use of requested nodes
commonSubmitArgs = iAppendArgument(commonSubmitArgs, ap, ...
    'RequireExclusiveNode', 'logical', '--exclusive');

% Reservation
commonSubmitArgs = iAppendArgument(commonSubmitArgs, ap, ...
    'Reservation', 'char', '--reservation=%s');

% Email notification
commonSubmitArgs = iAppendArgument(commonSubmitArgs, ap, ...
    'EmailAddress', 'char', '--mail-type=ALL --mail-user=%s');

% Catch all: directly append anything in the AdditionalSubmitArgs
commonSubmitArgs = iAppendArgument(commonSubmitArgs, ap, ...
    'AdditionalSubmitArgs', 'char', '%s');

% Trim any whitespace
commonSubmitArgs = strtrim(commonSubmitArgs);

end

function commonSubmitArgs = iAppendArgument(commonSubmitArgs, ap, propName, propType, submitPattern, defaultValue)
% Helper fcn to append a scheduler option to the submit string.
% Inputs:
%  commonSubmitArgs: submit string to append to
%  ap: AdditionalProperties object
%  propName: name of the property
%  propType: type of the property, i.e. char, double or logical
%  submitPattern: sprintf-style string specifying the format of the scheduler option
%  defaultValue (optional): value to use if the property is not specified in ap

if nargin < 6
    defaultValue = [];
end
arg = validatedPropValue(ap, propName, propType, defaultValue);
if ~isempty(arg) && (~islogical(arg) || arg)
    commonSubmitArgs = [commonSubmitArgs, ' ', sprintf(submitPattern, arg)];
end
end

function commonSubmitArgs = iAppendRequiredArgument(commonSubmitArgs, ap, propName, propType, submitPattern, errMsg) %#ok<DEFNU>
% Helper fcn to append a required scheduler option to the submit string.
% An error is thrown if the property is not specified in AdditionalProperties or is empty.
% Inputs:
%  commonSubmitArgs: submit string to append to
%  ap: AdditionalProperties object
%  propName: name of the property
%  propType: type of the property, i.e. char, double or logical
%  submitPattern: sprintf-style string specifying the format of the scheduler option
%  errMsg (optional): text to append to the error message if the property is not specified in ap

if ~isprop(ap, propName)
    errorText = sprintf('Required field %s is missing from AdditionalProperties.', propName);
    if nargin > 5
        errorText = [errorText newline errMsg];
    end
    error('parallelexamples:GenericSLURM:MissingAdditionalProperties', errorText);
elseif isempty(ap.(propName))
    errorText = sprintf('Required field %s is empty in AdditionalProperties.', propName);
    if nargin > 5
        errorText = [errorText newline errMsg];
    end
    error('parallelexamples:GenericSLURM:EmptyAdditionalProperties', errorText);
end
commonSubmitArgs = iAppendArgument(commonSubmitArgs, ap, propName, propType, submitPattern);
end
