clear; clc; close all;
addpath('multi_city_analysis');

cfg.name       = 'Atlanta';
cfg.urbanLabel = 'Hartsfield-Jackson';
cfg.ruralLabel = 'Calhoun Exp Stn';
cfg.urbanPath  = 'data/atlanta_urban.csv';   % USW00013874
cfg.ruralPath  = 'data/atlanta_rural.csv';   % USC00091500
cfg.yrs        = [1990 2024];
cfg.baseYrs    = [1985 2014];
cfg.figDir     = 'figures/atlanta';

cityAnalysis(cfg);
