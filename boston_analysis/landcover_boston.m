clear; clc;

% --- Load Boston HUC-12 list and CONUS land-cover tables ---
bostonHucs = loadHuc('data/boston_huc12_list.csv');
imperv     = loadHuc('data/Impervious_CONUS.csv',    'PIMPV',     'ImpervFrac');
canopy     = loadHuc('data/PCanopy_CONUS.csv',       'pCanopy',   'TreeCanopyPct');
pop        = loadHuc('data/Population_by_HUC12.csv', 'HUC12_Pop', 'Population');

fprintf('Boston HUC-12s to extract: %d\n', height(bostonHucs));

% --- Join the three CONUS tables onto the Boston list ---
lc = outerjoin(bostonHucs, imperv, 'Keys','HUC_12','MergeKeys',true,'Type','left');
lc = outerjoin(lc,         canopy, 'Keys','HUC_12','MergeKeys',true,'Type','left');
lc = outerjoin(lc,         pop,    'Keys','HUC_12','MergeKeys',true,'Type','left');
lc.Population = round(lc.Population);
lc.HUC_12     = string(lc.HUC_12);
lc.Name       = string(lc.Name);

writetable(lc, 'data/boston_landcover.csv');
fprintf('Wrote %d rows -> data/boston_landcover.csv\n\n', height(lc));

% --- Summary stats ---
weighted_imperv = sum(lc.ImpervFrac    .* lc.Population, 'omitnan') / sum(lc.Population, 'omitnan');
weighted_canopy = sum(lc.TreeCanopyPct .* lc.Population, 'omitnan') / sum(lc.Population, 'omitnan');
fprintf('Mean impervious cover:               %.1f%%\n', mean(lc.ImpervFrac,    'omitnan'));
fprintf('Mean tree canopy:                    %.1f%%\n', mean(lc.TreeCanopyPct, 'omitnan'));
fprintf('Population-weighted mean impervious: %.1f%%\n', weighted_imperv);
fprintf('Population-weighted mean canopy:     %.1f%%\n', weighted_canopy);
fprintf('Total population:                    %d\n',     sum(lc.Population,     'omitnan'));

% --- Figure 1: impervious vs canopy, colored by population ---
figure('Color','w');
scatter(lc.ImpervFrac, lc.TreeCanopyPct, 60, lc.Population, 'filled');
colormap(hot); cb = colorbar; cb.Label.String = 'Population';
xlabel('Impervious Surface (%)'); ylabel('Tree Canopy (%)');
title('Boston HUC-12 Watersheds — Land Cover'); grid on;
saveas(gcf, 'figures/boston_landcover_scatter.png');

% --- Figure 2: top 15 most populated watersheds, impervious vs canopy ---
sub = sortrows(rmmissing(lc), 'Population', 'descend');
top = flipud(sub(1:min(15, height(sub)), :));

figure('Color','w','Position',[100 100 900 600]);
b = barh([top.ImpervFrac, top.TreeCanopyPct], 'grouped');
b(1).FaceColor = [0.85 0.33 0.10];
b(2).FaceColor = [0.20 0.60 0.30];
set(gca, 'YTick', 1:height(top), 'YTickLabel', top.Name, ...
         'TickLabelInterpreter','none');
xlabel('Percent of watershed area (%)');
title('Top 15 Boston Watersheds by Population — Impervious vs Tree Canopy');
legend({'Impervious','Tree canopy'}, 'Location','southeast');
grid on; box on;
saveas(gcf, 'figures/boston_top_watersheds_bars.png');

% --- Connect to analysis_boston: anchor land cover to the observed UHI ---
% Logan Airport and Blue Hill Observatory each sit inside a HUC-12. We use
% the observed Logan-vs-Blue-Hill UHI to calibrate a per-% impervious
% sensitivity, then project an estimated UHI onto every Boston watershed.
station = struct('Logan',"Mystic River", 'BlueHill',"Outlet Neponset River");
uhi     = loadUhi();

iU = lc.Name == station.Logan;
iR = lc.Name == station.BlueHill;
meanUHI = mean(uhi.UHI, 'omitnan');
sens    = meanUHI / (lc.ImpervFrac(iU) - lc.ImpervFrac(iR));   % deg C per % impervious
lc.UHI_est = sens * (lc.ImpervFrac - lc.ImpervFrac(iR));

fprintf('\n--- Land cover vs. observed UHI ---\n');
fprintf('%-9s -> %-25s  imperv %4.1f%%  canopy %4.1f%%  meanTMAX %.2f C\n', ...
    'Logan',    lc.Name(iU), lc.ImpervFrac(iU), lc.TreeCanopyPct(iU), mean(uhi.TMAX_U,'omitnan'));
fprintf('%-9s -> %-25s  imperv %4.1f%%  canopy %4.1f%%  meanTMAX %.2f C\n', ...
    'BlueHill', lc.Name(iR), lc.ImpervFrac(iR), lc.TreeCanopyPct(iR), mean(uhi.TMAX_R,'omitnan'));
fprintf('Observed UHI (Logan - BlueHill): %.2f C\n', meanUHI);
fprintf('Implied sensitivity:             %.3f C per %% impervious\n', sens);

% --- Figure 3: land-cover-implied UHI gradient across Boston watersheds ---
figure('Color','w');
scatter(lc.ImpervFrac, lc.UHI_est, 60, lc.Population, 'filled'); hold on;
plot(lc.ImpervFrac(iU), lc.UHI_est(iU), 'kp', 'MarkerSize', 18, 'LineWidth', 1.5);
plot(lc.ImpervFrac(iR), lc.UHI_est(iR), 'kp', 'MarkerSize', 18, 'LineWidth', 1.5);
text(lc.ImpervFrac(iU)+1, lc.UHI_est(iU), 'Logan',     'FontWeight','bold');
text(lc.ImpervFrac(iR)+1, lc.UHI_est(iR), 'Blue Hill', 'FontWeight','bold');
colormap(hot); cb = colorbar; cb.Label.String = 'Population';
xlabel('Impervious Surface (%)');
ylabel('Estimated UHI vs. Blue Hill watershed (\circC)');
title(sprintf('Boston UHI gradient implied by land cover (calibrated on %.2f \\circC obs)', meanUHI));
grid on;
saveas(gcf, 'figures/boston_uhi_gradient.png');

% --- Spatial clustering: do urban watersheds cluster around Logan? ---
% No lat/lon in our table, but the HUC code encodes basin hierarchy:
% the first 8 digits are the HUC-8 basin. Logan and Blue Hill both sit in
% 01090001 (Charles / Boston Harbor coastal). If urbanization clusters
% around Logan, that basin's mean impervious should top the list.
lc.HUC_8 = extractBefore(lc.HUC_12, 9);
[gid, key] = findgroups(lc.HUC_8);
basins = table(key, ...
    splitapply(@numel,                       lc.HUC_12,       gid), ...
    splitapply(@(x) mean(x,'omitnan'),       lc.ImpervFrac,   gid), ...
    splitapply(@(x) mean(x,'omitnan'),       lc.TreeCanopyPct,gid), ...
    splitapply(@(x) sum(x, 'omitnan'),       lc.Population,   gid), ...
    'VariableNames', {'HUC_8','N','MeanImperv','MeanCanopy','Population'});
basins.Name = arrayfun(@basinName, basins.HUC_8);
basins      = sortrows(basins, 'MeanImperv', 'descend');

fprintf('\n--- HUC-8 basin clustering ---\n');
disp(basins(:, {'Name','N','MeanImperv','MeanCanopy','Population'}));

loganBasin = extractBefore(lc.HUC_12(iU), 9);

% --- Figure 4: mean impervious by basin, Logan basin highlighted ---
figure('Color','w','Position',[100 100 800 450]);
clr = repmat([0.5 0.5 0.5], height(basins), 1);
clr(basins.HUC_8 == loganBasin, :) = [0.85 0.33 0.10];
b4 = bar(basins.MeanImperv, 'FaceColor','flat'); b4.CData = clr;
set(gca, 'XTick', 1:height(basins), 'XTickLabel', basins.Name, ...
         'XTickLabelRotation', 20, 'TickLabelInterpreter','none');
ylabel('Mean impervious cover (%)');
title('Boston-area HUC-8 basins (Logan/Blue Hill basin in orange)');
grid on; box on;
saveas(gcf, 'figures/boston_basin_impervious.png');

% --- Helpers ---
function T = loadHuc(path, srcCol, newCol)
    opts = detectImportOptions(path);
    opts = setvartype(opts, 'HUC_12', 'string');
    T = readtable(path, opts);
    if nargin == 3
        T = T(:, {'HUC_12', srcCol});
        T.Properties.VariableNames{srcCol} = newCol;
    end
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

function T = loadUhi()
    u = readtable('data/boston_urban.csv');
    r = readtable('data/boston_rural.csv');
    if ~isdatetime(u.DATE), u.DATE = datetime(u.DATE, 'InputFormat','yyyy-MM-dd'); end
    if ~isdatetime(r.DATE), r.DATE = datetime(r.DATE, 'InputFormat','yyyy-MM-dd'); end
    u.TMAX(u.TMAX == -9999) = NaN;
    r.TMAX(r.TMAX == -9999) = NaN;
    inRange = @(x) x(year(x.DATE) >= 1990 & year(x.DATE) <= 2024 & ~isnan(x.TMAX), :);
    u = inRange(u); r = inRange(r);
    [~, ia, ib] = intersect(u.DATE, r.DATE);
    T = table(u.DATE(ia), u.TMAX(ia), r.TMAX(ib), u.TMAX(ia) - r.TMAX(ib), ...
              'VariableNames', {'DATE','TMAX_U','TMAX_R','UHI'});
end
