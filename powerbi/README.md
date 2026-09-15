# Power BI Dashboard

The interactive `.pbix` file is too large to store directly in this repository (172MB, exceeding GitHub's standard file size limits). It's available instead via this repository's **Releases** page:

**[Download the Power BI dashboard (.pbix)](../../releases)**

*(Update this link to point to the specific release once published.)*

## What's included

A 4-page interactive dashboard built on the project's cleaned data outputs:

1. **Portfolio Overview** — KPI cards, loan status split, charge-off rate by grade, state map
2. **Risk Segmentation** — risk tier breakdown, FICO band analysis, an interactive Grade × DTI heatmap matrix, with slicers for Grade, Risk Tier, State, and Purpose
3. **Trends & Borrower Profile** — vintage trend, loan purpose analysis, loan amount/income distributions, a grade risk-profile bubble chart
4. **Approval Funnel** — accepted vs. rejected applicant comparison

See the main [README](../README.md) for embedded screenshots of each page.

## To open it yourself

1. Download the `.pbix` from the Releases link above
2. Reproduce `accepted_final.csv` and `rejected_final.csv` by running the notebook (see `data/README.md`)
3. Open the `.pbix` in Power BI Desktop — if prompted, point the data source to your local copies of the two CSVs
