clear; clc; close all;
urban = readtable('data/boston_urban.csv');
rural = readtable('data/boston_rural.csv');
if ~isdatetime(urban.DATE)
    urban.DATE = datetime(urban.DATE, 'InputFormat', 'yyyy-MM-dd');
end
if ~isdatetime(rural.DATE)
    rural.DATE = datetime(rural.DATE, 'InputFormat', 'yyyy-MM-dd');
end
urban = urban(year(urban.DATE) >= 1990 & year(urban.DATE) <= 2024, :);
rural = rural(year(rural.DATE) >= 1990 & year(rural.DATE) <= 2024, :);
urban.TMAX(urban.TMAX == -9999) = NaN;
rural.TMAX(rural.TMAX == -9999) = NaN;
urban = urban(~isnan(urban.TMAX), :);
rural = rural(~isnan(rural.TMAX), :);
fprintf('Urban rows: %d\n', height(urban));
fprintf('Rural rows: %d\n', height(rural));
[~, ia, ib] = intersect(urban.DATE, rural.DATE);
fprintf('Matched days: %d\n', numel(ia));
T        = table();
T.DATE   = urban.DATE(ia);
T.TMAX   = urban.TMAX(ia);
T.TMAX_r = rural.TMAX(ib);
T.UHI    = T.TMAX - T.TMAX_r;
T.year   = year(T.DATE);
T.month  = month(T.DATE);

months      = (datetime(1990,1,1) : calmonths(1) : datetime(2024,12,1))';
urban_monthly = arrayfun(@(y,m) mean(urban.TMAX(urban.DATE.Year == y & month(urban.DATE) == m), 'omitnan'), ...
                         year(months), month(months));
rural_monthly = arrayfun(@(y,m) mean(rural.TMAX(rural.DATE.Year == y & month(rural.DATE) == m), 'omitnan'), ...
                         year(months), month(months));
monthlyMean = arrayfun(@(y,m) mean(T.UHI(T.year == y & T.month == m), 'omitnan'), ...
              year(months), month(months));

fprintf('Mean UHI 1990-2024: %.2f deg C\n', mean(T.UHI, 'omitnan'));

valid          = ~isnan(monthlyMean);
months_plot    = months(valid);
monthly_plot   = monthlyMean(valid);

figure;
plot(months_plot, urban_monthly, 'r-', 'LineWidth', 1, 'DisplayName', 'Logan Airport (Urban)');
hold on;
plot(months_plot, rural_monthly, 'b-', 'LineWidth', 1, 'DisplayName', 'Blue Hill (Rural)');
xlabel('Date');
ylabel('T_{max}  (°C)');
title('Boston T_{max} — Logan Airport vs. Blue Hill (1990–2024)');
legend('Location', 'best');
grid on;



figure;
p = polyfit(datenum(months_plot), monthly_plot, 1);
plot(months_plot, monthly_plot, 'b-', 'LineWidth', 1);
hold on;
plot(months_plot, polyval(p, datenum(months_plot)), 'r--', 'LineWidth', 1.5);
yline(0, 'k:', 'LineWidth', 1);
xlabel('Date');
ylabel('\DeltaT_{max}  (°C)');
title('Boston UHI Intensity — Logan Airport vs. Blue Hill (1990–2024)');
legend('Monthly mean', sprintf('Trend (%.4f °C/month)', p(1)), 'Location', 'best');
grid on;

smoothed = movmean(monthly_plot, 8, 'omitnan');
plot(months_plot, smoothed, 'k-', 'LineWidth', 2, 'DisplayName', '8-month smoothed');


r = corr(T.TMAX, T.TMAX_r, 'rows', 'complete');
fprintf('Correlation (Logan vs Blue Hill): r = %.4f\n', r);

pct_colder = sum(T.UHI < 0) / height(T) * 100;
fprintf('Days Logan colder than Blue Hill: %.1f%%\n', pct_colder);

% breakdown by season
seasons = [12 1 2; 3 4 5; 6 7 8; 9 10 11];
season_names = {'Winter','Spring','Summer','Fall'};
for s = 1:4
    idx = ismember(T.month, seasons(s,:));
    fprintf('%s mean UHI: %.2f C\n', season_names{s}, mean(T.UHI(idx), 'omitnan'));
end


figure;
scatter(T.TMAX_r, T.TMAX, 5, T.month, 'filled');
colormap(hsv);
cb = colorbar;
cb.Label.String = 'Month';
clim([1 12]);
hold on;
p2 = polyfit(T.TMAX_r, T.TMAX, 1);
x_fit = linspace(min(T.TMAX_r), max(T.TMAX_r), 100);
plot(x_fit, polyval(p2, x_fit), 'k-', 'LineWidth', 2);
plot(x_fit, x_fit, 'k--', 'LineWidth', 1.5);
r = corr(T.TMAX, T.TMAX_r, 'rows', 'complete');
text(0.05, 0.95, sprintf('r = %.4f', r), 'Units', 'normalized', 'FontSize', 12);
xlabel('Blue Hill T_{max} (°C)');
ylabel('Logan Airport T_{max} (°C)');
title('Logan vs. Blue Hill Daily T_{max} (1990–2024)');
legend('Daily obs', 'Regression', '1:1 line', 'Location', 'southeast');
grid on;


% breakdown extreme heat events

urban_raw = readtable('data/boston_urban.csv');
rural_raw = readtable('data/boston_rural.csv');
if ~isdatetime(urban_raw.DATE)
    urban_raw.DATE = datetime(urban_raw.DATE, 'InputFormat', 'yyyy-MM-dd');
end
urban_raw.TMAX(urban_raw.TMAX == -9999) = NaN;
rural_raw.TMAX(rural_raw.TMAX == -9999) = NaN;


p90_urban = prctile(urban_raw.TMAX(year(urban_raw.DATE) >= 1981 & year(urban_raw.DATE) <= 2010), 90);
p90_rural = prctile(rural_raw.TMAX(year(rural_raw.DATE) >= 1981 & year(rural_raw.DATE) <= 2010), 90);

fprintf('Urban 90th pctile (1981-2010): %.2f C\n', p90_urban);
fprintf('Rural 90th pctile (1981-2010): %.2f C\n', p90_rural);


count_90th_urban = sum(urban_raw.TMAX >= p90_urban);
count_90th_rural = sum(rural_raw.TMAX >= p90_rural);
fprintf('Urban days above 90th pctile: %d\n', count_90th_urban);
fprintf('Rural days above 90th pctile: %d\n', count_90th_rural);


years = (1990:2024)';
hw_urban = zeros(length(years), 1);
hw_rural = zeros(length(years), 1);

for i = 1:length(years)
    hw_urban(i) = sum(urban.TMAX(year(urban.DATE) == years(i)) >= p90_urban);
    hw_rural(i) = sum(rural.TMAX(year(rural.DATE) == years(i)) >= p90_rural);
end

% how often does each station have an unusually hot day relative to its own climate
figure;
plot(years, hw_urban, 'r-o', 'LineWidth', 1.5, 'MarkerSize', 5, 'DisplayName', 'Logan (Urban)');
hold on;
plot(years, hw_rural, 'b-o', 'LineWidth', 1.5, 'MarkerSize', 5, 'DisplayName', 'Blue Hill (Rural)');
xlabel('Year');
ylabel('Days exceeding 90th percentile');
title('Extreme Heat Days — Logan Airport vs. Blue Hill (1990–2024)');
legend('Location', 'best');
grid on;

hold on;
p_u = polyfit(years, hw_urban, 1);
p_r = polyfit(years, hw_rural, 1);
plot(years, polyval(p_u, years), 'r--', 'LineWidth', 1.5, 'DisplayName', 'Logan trend');
plot(years, polyval(p_r, years), 'b--', 'LineWidth', 1.5, 'DisplayName', 'Blue Hill trend');

