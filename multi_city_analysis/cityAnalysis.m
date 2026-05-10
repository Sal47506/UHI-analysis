function cityAnalysis(cfg)
% Full single-city UHI analysis. Required cfg fields:
%   name, urbanLabel, ruralLabel, urbanPath, ruralPath, yrs, baseYrs, figDir
    if ~isfolder(cfg.figDir), mkdir(cfg.figDir); end

    [u, r, T] = loadPair(cfg.urbanPath, cfg.ruralPath, cfg.yrs);
    printSummary(cfg, u, r, T);

    plotMonthlyTmax(cfg, u, r);
    plotUhiTrend(cfg, T);
    plotDailyScatter(cfg, T);
    plotExtremeHeat(cfg, u, r);
end

% ---------------------------------------------------------------------
function printSummary(cfg, u, r, T)
    fprintf('\n========== %s ==========\n', cfg.name);
    fprintf('Urban rows: %d   Rural rows: %d   Matched days: %d\n', ...
            height(u), height(r), height(T));
    fprintf('Mean UHI (%d-%d): %.2f C\n', cfg.yrs(1), cfg.yrs(2), mean(T.UHI, 'omitnan'));
    fprintf('Correlation r:    %.4f\n', corr(T.TMAX_U, T.TMAX_R, 'rows', 'complete'));
    fprintf('Days urban < rural: %.1f%%\n', sum(T.UHI < 0) / height(T) * 100);

    seasons = {[12 1 2], [3 4 5], [6 7 8], [9 10 11]};
    labels  = {'Winter', 'Spring', 'Summer', 'Fall'};
    m = month(T.DATE);
    for k = 1:4
        fprintf('  %-6s mean UHI: %+.2f C\n', labels{k}, ...
                mean(T.UHI(ismember(m, seasons{k})), 'omitnan'));
    end
end

% ---------------------------------------------------------------------
function plotMonthlyTmax(cfg, u, r)
    months = monthAxis(cfg.yrs);
    um = monthlyMean(u, 'TMAX', months);
    rm = monthlyMean(r, 'TMAX', months);

    figure('Color', 'w');
    plot(months, um, 'r-', 'LineWidth', 1, 'DisplayName', [cfg.urbanLabel ' (Urban)']);
    hold on;
    plot(months, rm, 'b-', 'LineWidth', 1, 'DisplayName', [cfg.ruralLabel ' (Rural)']);
    xlabel('Date'); ylabel('T_{max} (\circC)');
    title(sprintf('%s T_{max} — %s vs. %s (%d-%d)', ...
          cfg.name, cfg.urbanLabel, cfg.ruralLabel, cfg.yrs(1), cfg.yrs(2)));
    legend('Location', 'best'); grid on;
    saveFig(cfg, 'tmax_monthly');
end

% ---------------------------------------------------------------------
function plotUhiTrend(cfg, T)
    months = monthAxis(cfg.yrs);
    uhi    = monthlyMean(T, 'UHI', months);
    valid  = ~isnan(uhi);
    months = months(valid); uhi = uhi(valid);

    p              = polyfit(datenum(months), uhi, 1);
    trendPerDecade = p(1) * 365.25 * 10;

    figure('Color', 'w');
    plot(months, uhi, 'b-', 'LineWidth', 1, 'DisplayName', 'Monthly mean'); hold on;
    plot(months, polyval(p, datenum(months)), 'r--', 'LineWidth', 1.5, ...
         'DisplayName', sprintf('Trend (%+.2f \\circC/decade)', trendPerDecade));
    plot(months, movmean(uhi, 8, 'omitnan'), 'k-', 'LineWidth', 2, ...
         'DisplayName', '8-month smoothed');
    yline(0, 'k:', 'HandleVisibility', 'off');
    xlabel('Date'); ylabel('\Delta T_{max} (\circC)');
    title(sprintf('%s UHI Intensity — %s vs. %s (%d-%d)', ...
          cfg.name, cfg.urbanLabel, cfg.ruralLabel, cfg.yrs(1), cfg.yrs(2)));
    legend('Location', 'best'); grid on;
    saveFig(cfg, 'uhi_trend');
    fprintf('UHI trend: %+.3f C/decade\n', trendPerDecade);
end

% ---------------------------------------------------------------------
function plotDailyScatter(cfg, T)
    rUR  = corr(T.TMAX_U, T.TMAX_R, 'rows', 'complete');
    p    = polyfit(T.TMAX_R, T.TMAX_U, 1);
    xfit = linspace(min(T.TMAX_R), max(T.TMAX_R), 100);

    figure('Color', 'w');
    scatter(T.TMAX_R, T.TMAX_U, 5, month(T.DATE), 'filled');
    colormap(hsv); cb = colorbar; cb.Label.String = 'Month'; clim([1 12]);
    hold on;
    plot(xfit, polyval(p, xfit), 'k-',  'LineWidth', 2);
    plot(xfit, xfit,             'k--', 'LineWidth', 1.5);
    text(0.05, 0.95, sprintf('r = %.4f', rUR), ...
         'Units', 'normalized', 'FontSize', 12);
    xlabel(sprintf('%s T_{max} (\\circC)', cfg.ruralLabel));
    ylabel(sprintf('%s T_{max} (\\circC)', cfg.urbanLabel));
    title(sprintf('%s — Daily T_{max}: Urban vs. Rural (%d-%d)', ...
          cfg.name, cfg.yrs(1), cfg.yrs(2)));
    legend('Daily obs', 'Regression', '1:1 line', 'Location', 'southeast');
    grid on;
    saveFig(cfg, 'daily_scatter');
end

% ---------------------------------------------------------------------
function plotExtremeHeat(cfg, u, r)
    p90U = baselinePctile(u, cfg.baseYrs, 90);
    p90R = baselinePctile(r, cfg.baseYrs, 90);
    fprintf('Baseline %d-%d: 90th pctile urban=%.2f C  rural=%.2f C\n', ...
            cfg.baseYrs(1), cfg.baseYrs(2), p90U, p90R);

    yrs = (cfg.yrs(1):cfg.yrs(2))';
    hwU = exceedanceDays(u, p90U, yrs);
    hwR = exceedanceDays(r, p90R, yrs);
    [~, pU] = corr(yrs, hwU);
    [~, pR] = corr(yrs, hwR);
    fprintf('Extreme-day trend p-value: urban=%.3f  rural=%.3f\n', pU, pR);

    figure('Color', 'w');
    plot(yrs, hwU, 'r-o', 'LineWidth', 1.5, 'MarkerSize', 5, ...
         'DisplayName', [cfg.urbanLabel ' (Urban)']); hold on;
    plot(yrs, hwR, 'b-o', 'LineWidth', 1.5, 'MarkerSize', 5, ...
         'DisplayName', [cfg.ruralLabel ' (Rural)']);
    plot(yrs, polyval(polyfit(yrs, hwU, 1), yrs), 'r--', 'LineWidth', 1.5, ...
         'DisplayName', sprintf('Urban trend (p=%.2f)', pU));
    plot(yrs, polyval(polyfit(yrs, hwR, 1), yrs), 'b--', 'LineWidth', 1.5, ...
         'DisplayName', sprintf('Rural trend (p=%.2f)', pR));
    xlabel('Year'); ylabel('Days exceeding own 90th pctile');
    title(sprintf('%s — Extreme Heat Days (%d-%d)', cfg.name, cfg.yrs(1), cfg.yrs(2)));
    legend('Location', 'best'); grid on;
    saveFig(cfg, 'extreme_heat');
end

% ---------------------------------------------------------------------
function months = monthAxis(yrs)
    months = (datetime(yrs(1), 1, 1) : calmonths(1) : datetime(yrs(2), 12, 1))';
end

function v = monthlyMean(tbl, col, months)
    v = arrayfun(@(y, m) mean(tbl.(col)(year(tbl.DATE) == y & month(tbl.DATE) == m), ...
                              'omitnan'), year(months), month(months));
end

function p = baselinePctile(tbl, baseYrs, pct)
    base = tbl.TMAX(year(tbl.DATE) >= baseYrs(1) & year(tbl.DATE) <= baseYrs(2));
    p    = prctile(base, pct);
end

function n = exceedanceDays(tbl, threshold, yrs)
    n = arrayfun(@(y) sum(tbl.TMAX(year(tbl.DATE) == y) >= threshold), yrs);
end

function saveFig(cfg, tag)
    name = regexprep(lower(cfg.name), '[^a-z0-9]+', '_');
    saveas(gcf, fullfile(cfg.figDir, sprintf('%s_%s.png', name, tag)));
end
