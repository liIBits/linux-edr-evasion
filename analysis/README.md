# Analysis

Jupyter notebooks and output artifacts for analyzing experiment results.

## Files

| File | Purpose |
|------|---------|
| `analysis.ipynb` | Main analysis notebook — generates all metrics, figures, and tables |

## Usage

```bash
cd analysis
jupyter notebook analysis.ipynb
# Or: jupyter lab
```

Run all cells to generate outputs.

## Input

The notebook automatically loads the most recent CSV from:
- `../data/processed/runs_*.csv`

## Outputs

### Figures (`results/figures/`)

| Figure | Description |
|--------|-------------|
| `fig1_detection_rates.png` | Bar chart of detection rates by test case |
| `fig2_paired_comparison.png` | Traditional vs io_uring mean audit events |
| `fig3_boxplots.png` | Distribution of audit events (box plots) |
| `fig4_heatmap.png` | Detection heatmap by case and metric type |
| `fig5_evasion.png` | Evasion effectiveness (detection reduction %) |

### Tables (`results/tables/`)

| Table | Description |
|-------|-------------|
| `detection_rates.csv` | Detection rates by case (primary metric) |
| `false_negative_rates.csv` | False negative rates (1 - detection rate) |
| `time_to_detection.csv` | Median/mean time-to-detection |
| `syscall_bypass_validation.csv` | Statistical validation of syscall bypass |
| `mitre_mapping.csv` | MITRE ATT&CK technique mapping |

## Key Sections

1. **Setup** — imports, directory creation
2. **Load Data** — finds and loads CSV
3. **Preprocessing** — adds derived columns (method, operation, detection flags)
4. **Detection Rate Analysis** — primary metric
5. **False Negative Rate** — secondary metric
6. **Time-to-Detection** — latency metric
7. **Syscall Bypass Validation** — statistical proof that io_uring evades detection
8. **Visualizations** — publication-ready figures
9. **MITRE ATT&CK Mapping** — threat intelligence context
10. **Executive Summary** — auto-generated findings

## Dependencies

```bash
pip install pandas numpy matplotlib seaborn scipy jupyter
```
