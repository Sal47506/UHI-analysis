clear; clc; close all;
addpath('multi_city_analysis');
if ~isfolder('figures/boston'), mkdir('figures/boston'); end

LOGAN_BASIN    = "Mystic River";
BLUEHILL_BASIN = "Outlet Neponset River";

lc = buildLandCover();
writetable(lc, 'data/boston_landcover.csv');
fprintf('Wrote %d rows -> data/boston_landcover.csv\n\n', height(lc));

printSummary(lc);
plotLandCover(lc);
plotTopWatersheds(lc);

[uhi, lc] = calibrateUhi(lc, LOGAN_BASIN, BLUEHILL_BASIN);
printCalibration(uhi, lc, LOGAN_BASIN, BLUEHILL_BASIN);
plotUhiGradient(uhi, lc, LOGAN_BASIN, BLUEHILL_BASIN);

basins = basinClustering(lc);
fprintf('\n--- HUC-8 basin clustering ---\n');
disp(basins(:, {'Name','N','MeanImperv','MeanCanopy','Population'}));
plotBasins(lc, basins, LOGAN_BASIN);

% =====================================================================
function lc = buildLandCover()
    hucs   = loadHuc('data/boston_huc12_list.csv');
    imperv = loadHuc('data/Impervious_CONUS.csv',    'PIMPV',     'ImpervFrac');
    canopy = loadHuc('data/PCanopy_CONUS.csv',       'pCanopy',   'TreeCanopyPct');
    pop    = loadHuc('data/Population_by_HUC12.csv', 'HUC12_Pop', 'Population');

    fprintf('Boston HUC-12s to extract: %d\n', height(hucs));

    lc = outerjoin(hucs, imperv, 'Keys', 'HUC_12', 'MergeKeys', true, 'Type', 'left');
    lc = outerjoin(lc,   canopy, 'Keys', 'HUC_12', 'MergeKeys', true, 'Type', 'left');
    lc = outerjoin(lc,   pop,    'Keys', 'HUC_12', 'MergeKeys', true, 'Type', 'left');
    lc.Population = round(lc.Population);
    lc.HUC_12     = string(lc.HUC_12);
    lc.Name       = string(lc.Name);
end

function printSummary(lc)
    wImperv = weightedMean(lc.ImpervFrac,    lc.Population);
    wCanopy = weightedMean(lc.TreeCanopyPct, lc.Population);
    fprintf('Mean impervious cover:               %.1f%%\n', mean(lc.ImpervFrac,    'omitnan'));
    fprintf('Mean tree canopy:                    %.1f%%\n', mean(lc.TreeCanopyPct, 'omitnan'));
    fprintf('Population-weighted mean impervious: %.1f%%\n', wImperv);
    fprintf('Population-weighted mean canopy:     %.1f%%\n', wCanopy);
    fprintf('Total population:                    %d\n',     sum(lc.Population,     'omitnan'));
end

function plotLandCover(lc)
    figure('Color', 'w');
    scatter(lc.ImpervFrac, lc.TreeCanopyPct, 60, lc.Population, 'filled');
    colormap(hot); cb = colorbar; cb.Label.String = 'Population';
    xlabel('Impervious Surface (%)'); ylabel('Tree Canopy (%)');
    title('Boston HUC-12 Watersheds — Land Cover'); grid on;
    saveas(gcf, 'figures/boston/boston_landcover_scatter.png');
end

function plotTopWatersheds(lc)
    sorted = sortrows(rmmissing(lc), 'Population', 'descend');
    top    = flipud(sorted(1:min(15, height(sorted)), :));

    figure('Color', 'w', 'Position', [100 100 900 600]);
    b = barh([top.ImpervFrac, top.TreeCanopyPct], 'grouped');
    b(1).FaceColor = [0.85 0.33 0.10];
    b(2).FaceColor = [0.20 0.60 0.30];
    set(gca, 'YTick', 1:height(top), 'YTickLabel', top.Name, ...
             'TickLabelInterpreter', 'none');
    xlabel('Percent of watershed area (%)');
    title('Top 15 Boston Watersheds by Population — Impervious vs Tree Canopy');
    legend({'Impervious', 'Tree canopy'}, 'Location', 'southeast');
    grid on; box on;
    saveas(gcf, 'figures/boston/boston_top_watersheds_bars.png');
end

function [uhi, lc] = calibrateUhi(lc, urbanBasin, ruralBasin)
% Use the observed Logan-vs-Blue-Hill UHI to derive a per-% impervious
% sensitivity, then project it onto every Boston watershed.
    [~, ~, uhi] = loadPair('data/boston_urban.csv', 'data/boston_rural.csv', [1990 2024]);
    iU = lc.Name == urbanBasin;
    iR = lc.Name == ruralBasin;
    sens = mean(uhi.UHI, 'omitnan') / (lc.ImpervFrac(iU) - lc.ImpervFrac(iR));
    lc.UHI_est = sens * (lc.ImpervFrac - lc.ImpervFrac(iR));
end

function printCalibration(uhi, lc, urbanBasin, ruralBasin)
    iU = lc.Name == urbanBasin;
    iR = lc.Name == ruralBasin;
    meanUHI = mean(uhi.UHI, 'omitnan');
    sens = meanUHI / (lc.ImpervFrac(iU) - lc.ImpervFrac(iR));

    fprintf('\n--- Land cover vs. observed UHI ---\n');
    fprintf('%-9s -> %-25s  imperv %4.1f%%  canopy %4.1f%%  meanTMAX %.2f C\n', ...
            'Logan',    lc.Name(iU), lc.ImpervFrac(iU), lc.TreeCanopyPct(iU), ...
            mean(uhi.TMAX_U, 'omitnan'));
    fprintf('%-9s -> %-25s  imperv %4.1f%%  canopy %4.1f%%  meanTMAX %.2f C\n', ...
            'BlueHill', lc.Name(iR), lc.ImpervFrac(iR), lc.TreeCanopyPct(iR), ...
            mean(uhi.TMAX_R, 'omitnan'));
    fprintf('Observed UHI (Logan - BlueHill): %.2f C\n', meanUHI);
    fprintf('Implied sensitivity:             %.3f C per %% impervious\n', sens);
end

function plotUhiGradient(uhi, lc, urbanBasin, ruralBasin)
    iU = lc.Name == urbanBasin;
    iR = lc.Name == ruralBasin;
    meanUHI = mean(uhi.UHI, 'omitnan');

    figure('Color', 'w');
    scatter(lc.ImpervFrac, lc.UHI_est, 60, lc.Population, 'filled'); hold on;
    plot(lc.ImpervFrac(iU), lc.UHI_est(iU), 'kp', 'MarkerSize', 18, 'LineWidth', 1.5);
    plot(lc.ImpervFrac(iR), lc.UHI_est(iR), 'kp', 'MarkerSize', 18, 'LineWidth', 1.5);
    text(lc.ImpervFrac(iU) + 1, lc.UHI_est(iU), 'Logan',     'FontWeight', 'bold');
    text(lc.ImpervFrac(iR) + 1, lc.UHI_est(iR), 'Blue Hill', 'FontWeight', 'bold');
    colormap(hot); cb = colorbar; cb.Label.String = 'Population';
    xlabel('Impervious Surface (%)');
    ylabel('Estimated UHI vs. Blue Hill watershed (\circC)');
    title(sprintf('Boston UHI gradient implied by land cover (calibrated on %.2f \\circC obs)', meanUHI));
    grid on;
    saveas(gcf, 'figures/boston/boston_uhi_gradient.png');
end

function basins = basinClustering(lc)
% First 8 digits of HUC-12 = HUC-8 basin. Aggregate per basin so we can ask
% whether Logan's basin tops the impervious ranking.
    huc8 = extractBefore(lc.HUC_12, 9);
    [gid, key] = findgroups(huc8);
    basins = table(key, ...
        splitapply(@numel,                  lc.HUC_12,        gid), ...
        splitapply(@(x) mean(x, 'omitnan'), lc.ImpervFrac,    gid), ...
        splitapply(@(x) mean(x, 'omitnan'), lc.TreeCanopyPct, gid), ...
        splitapply(@(x) sum(x, 'omitnan'),  lc.Population,    gid), ...
        'VariableNames', {'HUC_8', 'N', 'MeanImperv', 'MeanCanopy', 'Population'});
    basins.Name = arrayfun(@basinName, basins.HUC_8);
    basins      = sortrows(basins, 'MeanImperv', 'descend');
end

function plotBasins(lc, basins, urbanBasin)
    loganBasin = extractBefore(lc.HUC_12(lc.Name == urbanBasin), 9);
    clr = repmat([0.5 0.5 0.5], height(basins), 1);
    clr(basins.HUC_8 == loganBasin, :) = [0.85 0.33 0.10];

    figure('Color', 'w', 'Position', [100 100 800 450]);
    b = bar(basins.MeanImperv, 'FaceColor', 'flat'); b.CData = clr;
    set(gca, 'XTick', 1:height(basins), 'XTickLabel', basins.Name, ...
             'XTickLabelRotation', 20, 'TickLabelInterpreter', 'none');
    ylabel('Mean impervious cover (%)');
    title('Boston-area HUC-8 basins (Logan/Blue Hill basin in orange)');
    grid on; box on;
    saveas(gcf, 'figures/boston/boston_basin_impervious.png');
end

% --- small utilities ---
function T = loadHuc(path, srcCol, newCol)
    opts = detectImportOptions(path);
    opts = setvartype(opts, 'HUC_12', 'string');
    T = readtable(path, opts);
    if nargin == 3
        T = T(:, {'HUC_12', srcCol});
        T.Properties.VariableNames{srcCol} = newCol;
    end
end

function w = weightedMean(x, w_)
    valid = ~isnan(x) & ~isnan(w_);
    w = sum(x(valid) .* w_(valid)) / sum(w_(valid));
end

function n = basinName(h)
    switch char(h)
        case '01090001', n = "Charles / Boston Harbor";
        case '01090002', n = "South Shore Coastal";
        case '01090004', n = "Cape Cod";
        case '01070005', n = "SuAsCo (inland)";
        case '01070006', n = "Lower Merrimack";
        otherwise,       n = "HUC-8 " + string(h);
    end
end
