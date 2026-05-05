function cityAnalysis(cfg)
% Run the full Boston-style UHI analysis for one city.
%   cfg.name        e.g. 'Phoenix'
%   cfg.urbanLabel  e.g. 'Sky Harbor'
%   cfg.ruralLabel  e.g. 'Sacaton'
%   cfg.urbanPath   path to urban TMAX CSV
%   cfg.ruralPath   path to rural TMAX CSV
%   cfg.yrs         analysis window, e.g. [1990 2024]
%   cfg.baseYrs     baseline window for 90th-pctile, e.g. [1985 2014]
%   cfg.figDir      output dir for PNGs, e.g. 'figures/phoenix'

if ~isfolder(cfg.figDir), mkdir(cfg.figDir); end

% --- Load + window urban / rural daily TMAX ---
u = readGhcn(cfg.urbanPath);
r = readGhcn(cfg.ruralPath);
u = u(year(u.DATE) >= cfg.yrs(1) & year(u.DATE) <= cfg.yrs(2), :);
r = r(year(r.DATE) >= cfg.yrs(1) & year(r.DATE) <= cfg.yrs(2), :);

[~, ia, ib] = intersect(u.DATE, r.DATE);
T = table(u.DATE(ia), u.TMAX(ia), r.TMAX(ib), u.TMAX(ia) - r.TMAX(ib), ...
          'VariableNames', {'DATE','TMAX_U','TMAX_R','UHI'});
T.year = year(T.DATE); T.month = month(T.DATE);

fprintf('\n========== %s ==========\n', cfg.name);
fprintf('Urban rows: %d   Rural rows: %d   Matched days: %d\n', ...
        height(u), height(r), height(T));
fprintf('Mean UHI (%d-%d): %.2f C\n', cfg.yrs(1), cfg.yrs(2), mean(T.UHI,'omitnan'));
fprintf('Correlation r:    %.4f\n', corr(T.TMAX_U, T.TMAX_R, 'rows','complete'));
fprintf('Days urban < rural: %.1f%%\n', sum(T.UHI < 0)/height(T)*100);

% --- Monthly aggregations on a common time axis ---
months = (datetime(cfg.yrs(1),1,1) : calmonths(1) : datetime(cfg.yrs(2),12,1))';
mAvg   = @(tbl, col) arrayfun(@(y,m) mean(tbl.(col)(year(tbl.DATE)==y & month(tbl.DATE)==m), 'omitnan'), ...
                              year(months), month(months));
um   = mAvg(u, 'TMAX');
rm   = mAvg(r, 'TMAX');
uhim = mAvg(T, 'UHI');

% --- Seasonal breakdown ---
seasons = [12 1 2; 3 4 5; 6 7 8; 9 10 11];
snames  = {'Winter','Spring','Summer','Fall'};
for s = 1:4
    idx = ismember(T.month, seasons(s,:));
    fprintf('  %-6s mean UHI: %+.2f C\n', snames{s}, mean(T.UHI(idx),'omitnan'));
end

% --- Figure 1: monthly TMAX urban vs rural ---
figure('Color','w');
plot(months, um, 'r-', 'LineWidth',1, 'DisplayName',sprintf('%s (Urban)', cfg.urbanLabel));
hold on;
plot(months, rm, 'b-', 'LineWidth',1, 'DisplayName',sprintf('%s (Rural)', cfg.ruralLabel));
xlabel('Date'); ylabel('T_{max} (\circC)');
title(sprintf('%s T_{max} — %s vs. %s (%d-%d)', ...
              cfg.name, cfg.urbanLabel, cfg.ruralLabel, cfg.yrs(1), cfg.yrs(2)));
legend('Location','best'); grid on;
saveFig(cfg, 'tmax_monthly');

% --- Figure 2: monthly UHI with linear trend + 8-month smoothing ---
valid = ~isnan(uhim);
mp = months(valid); up = uhim(valid);
p  = polyfit(datenum(mp), up, 1);
trendPerDecade = p(1) * 365.25 * 10;

figure('Color','w');
plot(mp, up, 'b-', 'LineWidth',1, 'DisplayName','Monthly mean'); hold on;
plot(mp, polyval(p, datenum(mp)), 'r--', 'LineWidth',1.5, ...
     'DisplayName', sprintf('Trend (%+.2f \\circC/decade)', trendPerDecade));
plot(mp, movmean(up, 8, 'omitnan'), 'k-', 'LineWidth',2, 'DisplayName','8-month smoothed');
yline(0, 'k:');
xlabel('Date'); ylabel('\Delta T_{max} (\circC)');
title(sprintf('%s UHI Intensity — %s vs. %s (%d-%d)', ...
              cfg.name, cfg.urbanLabel, cfg.ruralLabel, cfg.yrs(1), cfg.yrs(2)));
legend('Location','best'); grid on;
saveFig(cfg, 'uhi_trend');
fprintf('UHI trend: %+.3f C/decade\n', trendPerDecade);

% --- Figure 3: daily scatter urban vs rural, coloured by month ---
figure('Color','w');
scatter(T.TMAX_R, T.TMAX_U, 5, T.month, 'filled');
colormap(hsv); cb = colorbar; cb.Label.String = 'Month'; clim([1 12]); hold on;
p2   = polyfit(T.TMAX_R, T.TMAX_U, 1);
xfit = linspace(min(T.TMAX_R), max(T.TMAX_R), 100);
plot(xfit, polyval(p2, xfit), 'k-',  'LineWidth',2);
plot(xfit, xfit,             'k--', 'LineWidth',1.5);
text(0.05, 0.95, sprintf('r = %.4f', corr(T.TMAX_U, T.TMAX_R, 'rows','complete')), ...
     'Units','normalized', 'FontSize',12);
xlabel(sprintf('%s T_{max} (\\circC)', cfg.ruralLabel));
ylabel(sprintf('%s T_{max} (\\circC)', cfg.urbanLabel));
title(sprintf('%s — Daily T_{max}: Urban vs. Rural (%d-%d)', cfg.name, cfg.yrs(1), cfg.yrs(2)));
legend('Daily obs','Regression','1:1 line','Location','southeast');
grid on;
saveFig(cfg, 'daily_scatter');

% --- Extreme heat: 90th pctile of each station's own baseline climate ---
baseU = u.TMAX(year(u.DATE) >= cfg.baseYrs(1) & year(u.DATE) <= cfg.baseYrs(2));
baseR = r.TMAX(year(r.DATE) >= cfg.baseYrs(1) & year(r.DATE) <= cfg.baseYrs(2));
p90U  = prctile(baseU, 90);
p90R  = prctile(baseR, 90);
fprintf('Baseline %d-%d: 90th pctile urban=%.2f C  rural=%.2f C\n', ...
        cfg.baseYrs(1), cfg.baseYrs(2), p90U, p90R);

yrList = (cfg.yrs(1):cfg.yrs(2))';
hwU = arrayfun(@(y) sum(u.TMAX(year(u.DATE) == y) >= p90U), yrList);
hwR = arrayfun(@(y) sum(r.TMAX(year(r.DATE) == y) >= p90R), yrList);
[~, pU] = corr(yrList, hwU);
[~, pR] = corr(yrList, hwR);
fprintf('Extreme-day trend p-value: urban=%.3f  rural=%.3f\n', pU, pR);

% --- Figure 4: extreme heat days per year ---
figure('Color','w');
plot(yrList, hwU, 'r-o', 'LineWidth',1.5, 'MarkerSize',5, ...
     'DisplayName', sprintf('%s (Urban)', cfg.urbanLabel)); hold on;
plot(yrList, hwR, 'b-o', 'LineWidth',1.5, 'MarkerSize',5, ...
     'DisplayName', sprintf('%s (Rural)', cfg.ruralLabel));
plot(yrList, polyval(polyfit(yrList, hwU, 1), yrList), 'r--', 'LineWidth',1.5, ...
     'DisplayName', sprintf('Urban trend (p=%.2f)', pU));
plot(yrList, polyval(polyfit(yrList, hwR, 1), yrList), 'b--', 'LineWidth',1.5, ...
     'DisplayName', sprintf('Rural trend (p=%.2f)', pR));
xlabel('Year'); ylabel('Days exceeding own 90th pctile');
title(sprintf('%s — Extreme Heat Days (%d-%d)', cfg.name, cfg.yrs(1), cfg.yrs(2)));
legend('Location','best'); grid on;
saveFig(cfg, 'extreme_heat');

end

function saveFig(cfg, tag)
    saveas(gcf, fullfile(cfg.figDir, sprintf('%s_%s.png', lower(cfg.name), tag)));
end
