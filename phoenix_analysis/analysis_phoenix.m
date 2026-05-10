clear; clc; close all;
addpath('multi_city_analysis');

cfg.name       = 'Phoenix';
cfg.urbanLabel = 'Sky Harbor';
cfg.ruralLabel = 'Sacaton';
cfg.urbanPath  = 'data/phoenix_urban.csv';  % USW00023183
cfg.ruralPath  = 'data/phoenix_rural.csv';  % USC00026796
cfg.yrs        = [1990 2024];
cfg.baseYrs    = [1985 2014];
cfg.figDir     = 'figures/phoenix';

cityAnalysis(cfg);
