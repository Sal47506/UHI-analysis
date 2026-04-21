clear; clc;

opts = detectImportOptions('data/boston_huc12_list.csv');
opts = setvartype(opts, 'HUC_12', 'string');
bostonHucs = readtable('data/boston_huc12_list.csv', opts);

fprintf('Boston HUC-12s to extract: %d\n', height(bostonHucs));

imperv = loadConus('data/Impervious_CONUS.csv',    'PIMPV');
canopy = loadConus('data/PCanopy_CONUS.csv',       'pCanopy');
pop    = loadConus('data/Population_by_HUC12.csv', 'HUC12_Pop');

out = bostonHucs;
out.ImpervFrac    = NaN(height(out), 1);
out.TreeCanopyPct = NaN(height(out), 1);
out.Population    = NaN(height(out), 1);

for i = 1:height(out)
    h = out.HUC_12(i);

    j = find(imperv.HUC_12 == h, 1);
    if ~isempty(j), out.ImpervFrac(i) = imperv.VAL(j); end

    j = find(canopy.HUC_12 == h, 1);
    if ~isempty(j), out.TreeCanopyPct(i) = canopy.VAL(j); end

    j = find(pop.HUC_12 == h, 1);
    if ~isempty(j), out.Population(i) = round(pop.VAL(j)); end
end

writetable(out, 'data/boston_landcover.csv');
fprintf('Wrote %d rows -> data/boston_landcover.csv\n', height(out));
disp(head(out, 5));

function T = loadConus(path, valueCol)
    opts = detectImportOptions(path);
    opts = setvartype(opts, 'HUC_12', 'string');
    T = readtable(path, opts);
    T.VAL = T.(valueCol);
    T = T(:, {'HUC_12','VAL'});
end
