clear; clc; close all;
addpath(fileparts(mfilename('fullpath')));   % pick up sibling helpers (readGhcn)

% --- City config: GHCN station pairs (urban airport vs nearby rural COOP) ---
cities = { ...
    'Boston',  'USW00014739', 'USC00190736';   % Logan         vs Blue Hill
    'Phoenix', 'USW00023183', 'USC00026796';   % Sky Harbor    vs Sacaton
    'Atlanta', 'USW00013874', 'USC00091500';   % Hartsfield    vs Calhoun Exp Stn
};
yrs = [1990 2024];

% --- Fetch any missing station files from NOAA GHCN-Daily v1 service ---
for i = 1:size(cities, 1)
    name = lower(cities{i,1});
    fetchIfMissing(sprintf('data/%s_urban.csv', name), cities{i,2});
    fetchIfMissing(sprintf('data/%s_rural.csv', name), cities{i,3});
end

% --- Compute per-city UHI summaries ---
S = arrayfun(@(i) analyzeCity(cities{i,1}, ...
        sprintf('data/%s_urban.csv', lower(cities{i,1})), ...
        sprintf('data/%s_rural.csv', lower(cities{i,1})), yrs), ...
    (1:size(cities,1))');

% --- Comparison printout ---
fprintf('\n--- City UHI comparison (%d-%d) ---\n', yrs(1), yrs(2));
fprintf('%-9s %10s %12s %10s %10s %8s\n', ...
        'City','MeanUHI','Trend/dec','MeanT_U','MeanT_R','Days');
for i = 1:numel(S)
    fprintf('%-9s %10.2f %12.3f %10.2f %10.2f %8d\n', ...
        S(i).name, S(i).meanUHI, S(i).trendPerDecade, ...
        S(i).meanU, S(i).meanR, S(i).nDays);
end

% --- Figure 1: mean UHI per city ---
figure('Color','w');
b1 = bar([S.meanUHI], 'FaceColor','flat');
b1.CData = lines(numel(S));
set(gca, 'XTickLabel', {S.name});
ylabel('Mean UHI (\circC)');
title(sprintf('Urban Heat Island intensity by city (%d-%d)', yrs(1), yrs(2)));
grid on; box on;
saveas(gcf, 'figures/multicity_meanUHI.png');

% --- Figure 2: monthly UHI seasonal cycle ---
figure('Color','w'); hold on;
clr = lines(numel(S));
for i = 1:numel(S)
    plot(1:12, S(i).monthlyUHI, '-o', 'LineWidth', 2, 'Color', clr(i,:), ...
         'DisplayName', S(i).name);
end
yline(0, 'k:');
xticks(1:12); xticklabels({'J','F','M','A','M','J','J','A','S','O','N','D'});
xlabel('Month'); ylabel('Mean UHI (\circC)');
title('Seasonal UHI cycle by city');
legend('Location','best'); grid on;
saveas(gcf, 'figures/multicity_seasonal.png');

% --- Figure 3: yearly UHI time series with linear trend ---
figure('Color','w'); hold on;
for i = 1:numel(S)
    yr = S(i).yearly.year;  uhi = S(i).yearly.uhi;
    plot(yr, uhi, '-o', 'LineWidth', 1.2, 'Color', clr(i,:), 'MarkerSize', 4, ...
         'DisplayName', sprintf('%s (%.2f \\circC/dec)', S(i).name, S(i).trendPerDecade));
    plot(yr, polyval(polyfit(yr, uhi, 1), yr), '--', 'Color', clr(i,:), ...
         'HandleVisibility','off');
end
xlabel('Year'); ylabel('Annual mean UHI (\circC)');
title(sprintf('UHI trend by city (%d-%d)', yrs(1), yrs(2)));
legend('Location','best'); grid on;
saveas(gcf, 'figures/multicity_yearly.png');

% ============================== Helpers ==============================
function fetchIfMissing(localPath, stnId)
    if isfile(localPath), return; end
    url = sprintf(['https://www.ncei.noaa.gov/access/services/data/v1?' ...
        'dataset=daily-summaries&stations=%s&startDate=1985-01-01&' ...
        'endDate=2024-12-31&dataTypes=TMAX&format=csv&units=metric'], stnId);
    fprintf('Fetching %s -> %s\n', stnId, localPath);
    websave(localPath, url);
end

function s = analyzeCity(name, urbanPath, ruralPath, yrs)
    u = readGhcn(urbanPath);
    r = readGhcn(ruralPath);
    [~, ia, ib] = intersect(u.DATE, r.DATE);
    T = table(u.DATE(ia), u.TMAX(ia), r.TMAX(ib), u.TMAX(ia) - r.TMAX(ib), ...
              'VariableNames', {'DATE','TMAX_U','TMAX_R','UHI'});
    T = T(year(T.DATE) >= yrs(1) & year(T.DATE) <= yrs(2), :);

    s.name    = name;
    s.nDays   = height(T);
    s.meanU   = mean(T.TMAX_U, 'omitnan');
    s.meanR   = mean(T.TMAX_R, 'omitnan');
    s.meanUHI = mean(T.UHI,    'omitnan');
    s.monthlyUHI = arrayfun(@(m) mean(T.UHI(month(T.DATE) == m), 'omitnan'), 1:12);

    yrList = unique(year(T.DATE));
    yu     = arrayfun(@(y) mean(T.UHI(year(T.DATE) == y), 'omitnan'), yrList);
    s.yearly = table(yrList, yu, 'VariableNames', {'year','uhi'});
    p = polyfit(yrList, yu, 1);
    s.trendPerDecade = p(1) * 10;
end

