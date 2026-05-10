function run_all()
% Regenerate every figure and summary in one shot.
%   matlab -batch "run_all"

    repoRoot = fileparts(mfilename('fullpath'));
    cd(repoRoot);
    addpath(fullfile(repoRoot, 'multi_city_analysis'));
    addpath(fullfile(repoRoot, 'boston_analysis'));
    addpath(fullfile(repoRoot, 'phoenix_analysis'));
    addpath(fullfile(repoRoot, 'atlanta_analysis'));
    if ~isfolder('figures'), mkdir('figures'); end

    stages = {
        'uhi_compare'
        'uhi_vs_impervious'
        'analysis_boston'
        'landcover_boston'
        'analysis_phoenix'
        'analysis_atlanta'
        'analysis_atlanta_winder'
    };

    for k = 1:numel(stages)
        fprintf('\n================ %s ================\n', stages{k});
        cd(repoRoot); close all;
        try
            evalin('base', stages{k});
        catch ME
            fprintf(2, '!! %s failed: %s\n', stages{k}, ME.message);
        end
    end

    cd(repoRoot);
    fprintf('\nDone. Figures: %s\n', fullfile(repoRoot, 'figures'));
end
