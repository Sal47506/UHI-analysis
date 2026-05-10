% Cross-city scatter: mean 1990-2024 UHI vs. impervious-surface fraction.
% Impervious values come from data/city_impervious.csv (NLCD 2019).

clear; clc; close all;
addpath(fileparts(mfilename('fullpath')));
if ~isfolder('figures'), mkdir('figures'); end

cities = { ...
    'Boston',  'USW00014739', 'USC00190736', 'clean';
    'Phoenix', 'USW00023183', 'USC00026796', 'clean';
    'Houston', 'USW00012960', 'USC00415272', 'clean';
    'Atlanta', 'USW00013874', 'USC00091500', 'caveat';
};
yrs = [1990 2024];

S = arrayfun(@(i) citySummary(cities{i, 1}, ...
                              sprintf('data/%s_urban.csv', lower(cities{i, 1})), ...
                              sprintf('data/%s_rural.csv', lower(cities{i, 1})), ...
                              yrs, cities{i, 4}), ...
             (1:size(cities, 1))');

[data, fit] = joinImpervious(S, 'data/city_impervious.csv');

printScatterTable(data, fit, yrs);
plotScatter(data, fit);

% =====================================================================
function [data, fit] = joinImpervious(S, impervPath)
    imp   = readtable(impervPath, 'TextType', 'string');
    names = string({S.name})';
    [~, ia, ib] = intersect(names, imp.city, 'stable');
    if numel(ia) < numel(S)
        warning('Missing impervious entries for: %s', ...
                strjoin(setdiff(names, imp.city), ', '));
    end

    data.city    = names(ia);
    data.flag    = string({S(ia).flag})';
    data.uhi     = [S(ia).meanUHI]';
    data.trend   = [S(ia).trendPerDecade]';
    data.imperv  = imp.impervious_pct(ib);

    clean = data.flag == "clean";
    fit.clean   = clean;
    if nnz(clean) >= 2
        fit.poly   = polyfit(data.imperv(clean), data.uhi(clean), 1);
        fit.rClean = corr(data.imperv(clean), data.uhi(clean));
        fit.rAll   = corr(data.imperv, data.uhi);
    else
        fit.poly = []; fit.rClean = NaN; fit.rAll = NaN;
    end
end

function printScatterTable(data, fit, yrs)
    fprintf('\n--- UHI vs. impervious surface (%d-%d) ---\n', yrs(1), yrs(2));
    fprintf('%-9s %8s %10s %10s  %s\n', 'City', 'Imperv%', 'MeanUHI', 'Trend/dec', 'Flag');
    for i = 1:numel(data.city)
        fprintf('%-9s %8.1f %10.2f %10.3f  %s\n', ...
                data.city(i), data.imperv(i), data.uhi(i), data.trend(i), data.flag(i));
    end
    if ~isempty(fit.poly)
        fprintf('Slope (clean cities): %+.3f \xB0C per %% impervious\n', fit.poly(1));
        fprintf('Pearson r (clean):    %.3f   (n=%d)\n', fit.rClean, nnz(fit.clean));
        fprintf('Pearson r (all):      %.3f   (n=%d)\n', fit.rAll,   numel(data.uhi));
    end
end

function plotScatter(data, fit)
    figure('Color', 'w'); hold on;
    clr = lines(numel(data.city));
    for i = 1:numel(data.city)
        if data.flag(i) == "caveat"
            scatter(data.imperv(i), data.uhi(i), 140, clr(i, :), 'd', 'LineWidth', 1.6);
        else
            scatter(data.imperv(i), data.uhi(i), 140, clr(i, :), 'filled');
        end
        text(data.imperv(i) + 1.2, data.uhi(i), data.city(i), ...
             'FontSize', 11, 'FontWeight', 'bold');
    end
    if ~isempty(fit.poly)
        xfit = linspace(min(data.imperv) - 5, max(data.imperv) + 5, 100);
        plot(xfit, polyval(fit.poly, xfit), 'k--', 'LineWidth', 1.5, ...
             'DisplayName', sprintf('Linear fit: %+.3f \\circC/%%', fit.poly(1)));
        text(0.02, 0.97, sprintf('r = %.2f (clean, n=%d)', fit.rClean, nnz(fit.clean)), ...
             'Units', 'normalized', 'FontSize', 11);
    end
    text(0.02, 0.92, 'open diamond = elevation-mismatched rural ref', ...
         'Units', 'normalized', 'FontSize', 9, 'Color', [0.3 0.3 0.3]);
    xlabel('Impervious surface fraction (%, 5-km buffer, NLCD 2019)');
    ylabel('Mean UHI 1990-2024 (\circC)');
    title('Cross-city UHI intensity vs. urban land-cover');
    grid on; box on;
    saveas(gcf, 'figures/multicity_uhi_vs_impervious.png');
end
