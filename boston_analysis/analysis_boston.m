clear; clc; close all;
addpath('multi_city_analysis');

cfg.name       = 'Boston';
cfg.urbanLabel = 'Logan Airport';
cfg.ruralLabel = 'Blue Hill';
cfg.urbanPath  = 'data/boston_urban.csv';   % USW00014739
cfg.ruralPath  = 'data/boston_rural.csv';   % USC00190736
cfg.yrs        = [1990 2024];
cfg.baseYrs    = [1981 2010];
cfg.figDir     = 'figures/boston';

cityAnalysis(cfg);
