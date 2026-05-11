# Quantifying Urban Heat Island Intensification and Extreme Heat Trends Across U.S. Cities (Sal Nuhin)

Station-pair approach to quantifying Urban Heat Island (UHI) intensity, long-term trends and extreme heat exposure across four U.S. cities (Boston, Phoenix, Houston and Atlanta) from 1990–2024.

This repository contains the analysis materials for *Quantifying Urban Heat Island Intensification and Extreme Heat Trends Across U.S. Cities* (Nuhin, 2026). The MATLAB code downloads paired urban and rural daily-maximum-temperature records from NOAA GHCN-Daily, computes daily UHI intensity (`ΔTmax = Tmax,urban − Tmax,rural`), characterizes seasonal and annual trends, identifies extreme heat days against a fixed 1981–2010 baseline and relates UHI magnitude to impervious-surface cover both within Boston (HUC-12 watersheds) and across cities (NLCD 2019, 5-km airport buffer).

## Data Availability Statement

Daily maximum temperature records are publicly available from the NOAA Global Historical Climatology Network Daily archive via the [NOAA Climate Data Online portal](https://www.ncei.noaa.gov/cdo-web/). Station pairs used:

- Boston: Logan Airport (`USW00014739`) / Blue Hill Observatory (`USC00190736`)
- Phoenix: Sky Harbor (`USW00023183`) / Sacaton (`USC00026796`)
- Houston: Bush IAH (`USW00012960`) / Liberty (`USC00415272`)
- Atlanta: Hartsfield-Jackson (`USW00013874`) / Calhoun Exp Stn (`USC00091500`), with a sensitivity test against Winder 1 SSE (`USC00099157`)

`multi_city_analysis/fetchStation.m` downloads each TMAX series directly from the NCEI access API and caches it under `data/`.

Land-cover and watershed metrics for the within-city Boston analysis (impervious cover, tree canopy and population by HUC-12) are from the U.S. EPA [EnviroAtlas](https://www.epa.gov/enviroatlas). Cross-city impervious cover within a 5-km buffer of each urban station is from the 2019 [National Land Cover Database (NLCD)](https://doi.org/10.5066/P9KZCM54) and is summarized in `data/city_impervious.csv`.

## Analysis

MATLAB code for downloading station data, computing UHI metrics and producing every figure in the report. The top-level driver `run_all.m` regenerates all results from the cached `data/` CSVs.

### Top-level driver

- `run_all.m` Runs each analysis stage in order and writes outputs to `figures/`. Invoke from the repository root with `matlab -batch "run_all"`.

### Shared helpers (`multi_city_analysis/`)

- `fetchStation.m` Downloads a GHCN-Daily TMAX CSV from the NCEI access API if not already cached.
- `readGhcn.m` Reads an NCEI TMAX CSV, normalizes the date column to `datetime` and drops missing-flag (`-9999`) records.
- `loadPair.m` Loads a paired urban/rural TMAX series, restricts to a year window and returns a daily table with `UHI = TMAX_U − TMAX_R`.
- `citySummary.m` Per-city UHI summary: mean ΔTmax, monthly climatology, annual series and per-decade linear trend.
- `cityAnalysis.m` Full single-city pipeline: monthly Tmax series, ΔTmax trend with 8-month smoothing, daily urban-vs-rural scatter and annual extreme-heat-day counts against each station's own 1981–2010 (or 1985–2014) 90th percentile.

### Cross-city comparison

- `multi_city_analysis/uhi_compare.m` Runs `citySummary` over the four-city panel, prints the comparison table and writes the mean-UHI bar chart, seasonal cycle and annual-trend plot.
- `multi_city_analysis/uhi_vs_impervious.m` Joins per-city mean UHI to NLCD 2019 impervious fraction within a 5-km buffer of each urban station and produces the cross-city scatter.

### Per-city analyses

- `boston_analysis/analysis_boston.m` Runs `cityAnalysis` for the Logan / Blue Hill pair.
- `boston_analysis/landcover_boston.m` Joins the EPA EnviroAtlas HUC-12 tables to the Boston watershed list, calibrates a per-percent-impervious UHI sensitivity from the observed Logan / Blue Hill differential and projects it across all 27 watersheds.
- `phoenix_analysis/analysis_phoenix.m` Runs `cityAnalysis` for the Sky Harbor / Sacaton pair.
- `atlanta_analysis/analysis_atlanta.m` Runs `cityAnalysis` for the Hartsfield-Jackson / Calhoun pair (the elevation-mismatched default used in the report).
- `atlanta_analysis/analysis_atlanta_winder.m` Sensitivity rerun using Winder 1 SSE, which sits near Hartsfield-Jackson's elevation and removes most of the lapse-rate bias.

## Copying / Running this repository

### Local

You will need Git and MATLAB (R2020b or newer, with the Statistics and Machine Learning Toolbox for `prctile` and `corr`). For Git, see the [Git website](https://git-scm.com/).

In a terminal, navigate to where you want the cloned directory and run:

```bash
git clone https://github.com/Sal47506/UHI-analysis.git
cd UHI-analysis
```

Then launch the full pipeline from the repository root:

```matlab
run_all
```

or from a shell:

```bash
matlab -batch "run_all"
```

This downloads any missing GHCN-Daily station files into `data/`, regenerates every figure into `figures/` and prints the summary tables reproduced in the report.