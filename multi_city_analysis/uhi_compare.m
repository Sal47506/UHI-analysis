clear; clc; close all;
addpath(fileparts(mfilename('fullpath')));
if ~isfolder('figures'), mkdir('figures'); end

% name | urban GHCN id | rural GHCN id | flag ('clean' | 'caveat')
cities = { ...
    'Boston',  'USW00014739', 'USC00190736', 'clean';   % Logan       vs Blue Hill
    'Phoenix', 'USW00023183', 'USC00026796', 'clean';   % Sky Harbor  vs Sacaton
    'Houston', 'USW00012960', 'USC00415272', 'clean';   % Bush IAH    vs Liberty
    'Atlanta', 'USW00013874', 'USC00091500', 'caveat';  % Hartsfield  vs Calhoun (elev. mismatch)
};
yrs = [1990 2024];

S = computeCities(cities, yrs);
printTable(S, yrs);
plotMeanUHI(S, yrs);
plotSeasonalCycle(S);
plotYearlyTrend(S, yrs);

fprintf('\nNext: run uhi_vs_impervious for the cross-city scatter.\n');

% =====================================================================
function S = computeCities(cities, yrs)
    for i = 1:size(cities, 1)
        name = lower(cities{i, 1});
        fetchStation(sprintf('data/%s_urban.csv', name), cities{i, 2});
        fetchStation(sprintf('data/%s_rural.csv', name), cities{i, 3});
    end
    S = arrayfun(@(i) citySummary(cities{i, 1}, ...
                                  sprintf('data/%s_urban.csv', lower(cities{i, 1})), ...
                                  sprintf('data/%s_rural.csv', lower(cities{i, 1})), ...
                                  yrs, cities{i, 4}), ...
                 (1:size(cities, 1))');
end

function printTable(S, yrs)
    fprintf('\n--- City UHI comparison (%d-%d) ---\n', yrs(1), yrs(2));
    fprintf('%-9s %10s %12s %10s %10s %8s  %s\n', ...
            'City', 'MeanUHI', 'Trend/dec', 'MeanT_U', 'MeanT_R', 'Days', 'Flag');
    for i = 1:numel(S)
        fprintf('%-9s %10.2f %12.3f %10.2f %10.2f %8d  %s\n', ...
                S(i).name, S(i).meanUHI, S(i).trendPerDecade, ...
                S(i).meanU, S(i).meanR, S(i).nDays, S(i).flag);
    end
end

function plotMeanUHI(S, yrs)
    figure('Color', 'w');
    bars = bar([S.meanUHI], 'FaceColor', 'flat');
    bars.CData = lines(numel(S));
    for i = 1:numel(S)
        if isCaveat(S(i))
            bars.CData(i, :) = bars.CData(i, :) * 0.55;
            text(i, S(i).meanUHI + 0.08, '*', 'HorizontalAlignment', 'center', ...
                 'FontSize', 18, 'FontWeight', 'bold');
        end
    end
    set(gca, 'XTickLabel', {S.name});
    ylabel('Mean UHI (\circC)');
    title(sprintf('Urban Heat Island intensity by city (%d-%d)', yrs(1), yrs(2)));
    text(0.02, 0.97, '* rural-station elevation mismatch', ...
         'Units', 'normalized', 'FontSize', 9, 'Color', [0.3 0.3 0.3]);
    grid on; box on;
    saveas(gcf, 'figures/multicity_meanUHI.png');
end

function plotSeasonalCycle(S)
    figure('Color', 'w'); hold on;
    clr = lines(numel(S));
    for i = 1:numel(S)
        if isCaveat(S(i))
            plot(1:12, S(i).monthlyUHI, '--o', 'LineWidth', 1.6, 'Color', clr(i, :), ...
                 'DisplayName', [S(i).name '*']);
        else
            plot(1:12, S(i).monthlyUHI, '-o', 'LineWidth', 2, 'Color', clr(i, :), ...
                 'DisplayName', S(i).name);
        end
    end
    yline(0, 'k:', 'HandleVisibility', 'off');
    xticks(1:12); xticklabels({'J','F','M','A','M','J','J','A','S','O','N','D'});
    xlabel('Month'); ylabel('Mean UHI (\circC)');
    title('Seasonal UHI cycle by city');
    legend('Location', 'best'); grid on;
    saveas(gcf, 'figures/multicity_seasonal.png');
end

function plotYearlyTrend(S, yrs)
    figure('Color', 'w'); hold on;
    clr = lines(numel(S));
    for i = 1:numel(S)
        yr  = S(i).yearly.year;
        uhi = S(i).yearly.uhi;
        style = '-o'; if isCaveat(S(i)), style = '--o'; end
        plot(yr, uhi, style, 'LineWidth', 1.2, 'Color', clr(i, :), 'MarkerSize', 4, ...
             'DisplayName', sprintf('%s (%.2f \\circC/dec)', S(i).name, S(i).trendPerDecade));
        plot(yr, polyval(polyfit(yr, uhi, 1), yr), '--', 'Color', clr(i, :), ...
             'HandleVisibility', 'off');
    end
    xlabel('Year'); ylabel('Annual mean UHI (\circC)');
    title(sprintf('UHI trend by city (%d-%d)', yrs(1), yrs(2)));
    legend('Location', 'best'); grid on;
    saveas(gcf, 'figures/multicity_yearly.png');
end

function tf = isCaveat(s)
    tf = strcmp(s.flag, 'caveat');
end
