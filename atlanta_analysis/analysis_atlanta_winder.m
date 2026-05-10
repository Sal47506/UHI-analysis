% Sensitivity test: Atlanta UHI with Winder 1 SSE (USC00099157) as the
% rural reference. Winder sits at the same elevation as Hartsfield-Jackson,
% so this run removes the lapse-rate bias present in the default Calhoun pair.

clear; clc; close all;
addpath('multi_city_analysis');

cfg.name       = 'Atlanta_Winder';
cfg.urbanLabel = 'Hartsfield-Jackson';
cfg.ruralLabel = 'Winder 1 SSE';
cfg.urbanPath  = 'data/atlanta_urban.csv';            % USW00013874
cfg.ruralPath  = 'data/atlanta_rural_winder.csv';     % USC00099157
cfg.yrs        = [1990 2024];
cfg.baseYrs    = [1985 2014];
cfg.figDir     = 'figures/atlanta_winder';

fetchStation(cfg.ruralPath, 'USC00099157');
cityAnalysis(cfg);
