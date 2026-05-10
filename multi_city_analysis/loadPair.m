function [u, r, T] = loadPair(urbanPath, ruralPath, yrs)
% Load urban and rural TMAX CSVs, window to yrs = [y1 y2], and build a
% daily paired table with UHI = TMAX_U - TMAX_R on matching dates.
    u = inWindow(readGhcn(urbanPath), yrs);
    r = inWindow(readGhcn(ruralPath), yrs);

    [~, ia, ib] = intersect(u.DATE, r.DATE);
    T = table(u.DATE(ia), u.TMAX(ia), r.TMAX(ib), u.TMAX(ia) - r.TMAX(ib), ...
              'VariableNames', {'DATE', 'TMAX_U', 'TMAX_R', 'UHI'});
end

function T = inWindow(T, yrs)
    T = T(year(T.DATE) >= yrs(1) & year(T.DATE) <= yrs(2), :);
end
