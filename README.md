# AlphaScreen — M&A Target Screening System

### End-to-End BA Engagement Simulation | Strategy & Transactions

![MySQL](https://img.shields.io/badge/MySQL-8.x-4479A1?style=flat&logo=mysql&logoColor=white)
![Power BI](https://img.shields.io/badge/Power%20BI-Desktop-F2C811?style=flat&logo=powerbi&logoColor=black)
![draw.io](https://img.shields.io/badge/draw.io-BPMN-F08705?style=flat)
![GitHub](https://img.shields.io/badge/GitHub-triton1000-181717?style=flat&logo=github&logoColor=white)

---

## Business Context

AlphaScreen simulates a Strategy & Transactions BA engagement in which a PE fund commissioned a structured screening of S&P 500 companies to identify acquisition targets. The mandate was to replace a manual, analyst-dependent Excel process — consuming 3–4 analyst days per screening cycle — with a standardised scoring platform reducing cycle time to under 2 hours.

As the Business Analyst, my role was to define requirements, design the Deal Score methodology, build the SQL analytical layer, deliver a self-serve Power BI dashboard, and produce the full BA documentation suite: BRD, BPMN process diagrams, and a UAT test suite with Requirements Traceability Matrix.

---

## Deliverables

| # | Deliverable | Details |
|---|---|---|
| 1 | **MySQL** | Schema + 7 queries — DENSE_RANK inside CTE, chained CTEs, min-max normalisation, Deal Score |
| 2 | **Power BI** | 3-page dashboard — Universe Overview, Sector Deep Dive (drill-through), Opportunity Map |
| 3 | **BRD** | 10-section Business Requirements Document — FR-01 to FR-08, Data Dictionary, NFRs |
| 4 | **BPMN** | AS-IS and TO-BE process diagrams in draw.io — swimlanes, exclusive decision gateway |
| 5 | **UAT** | 12 test cases (TC-001 to TC-012) + Requirements Traceability Matrix + sign-off table |

---

## Dataset

**S&P 500 Companies with Financial Information**
Source: [github.com/datasets/s-and-p-500-companies-financials](https://github.com/datasets/s-and-p-500-companies-financials)
License: Open Data Commons PDL

~505 companies. Fields sourced from SEC filings: `ticker`, `name`, `sector`, `market_cap`, `ebitda`, `eps`, `pe_ratio`, `price_book`, `price_sales`, `div_yield`.

> Companies with NULL values in EPS, EBITDA, or Price/Book are excluded from Deal Score computation — these represent incomplete SEC filing records. All companies remain visible in the dashboard; only the Deal Score field returns blank for excluded rows.

---

## SQL — Query Highlights

| # | Query | Technique |
|---|---|---|
| Q1 | Sector-wise avg EBITDA and company count | GROUP BY, aggregate functions |
| Q2 | Top 3 companies by market cap per sector | **DENSE_RANK inside CTE**, PARTITION BY sector |
| Q3 | Valuation flag per company (Undervalued / Fair / Overvalued) | CASE WHEN, NULL handling |
| Q4 | Composite Deal Score via min-max normalisation | **Chained CTEs**, window functions for global MIN/MAX, NULLIF safe division |
| Q5 | Deal Score with sector rank and vs-sector-average delta | **CTE joined back to sector aggregate CTE**, DENSE_RANK in outer SELECT |
| Q6 | Risk classification (High / Medium / Low Risk) | CASE WHEN with compound conditions and IS NULL |
| Q7 | Top 10 acquisition targets by Deal Score | CTE + ORDER BY + LIMIT |

**Deal Score Formula:**
Deal Score = (0.4 × EPS_norm) + (0.3 × EBITDA_norm) + (0.3 × PB_norm)
where: X_norm = (X − MIN(X)) / (MAX(X) − MIN(X))
computed via window functions across the full dataset

---

## Power BI Dashboard

**DAX Measures:** Total Companies · Median Market Cap · High Risk Count · Sector Avg EBITDA · Avg Deal Score

**Page 1 — Universe Overview**
KPI cards (Total Companies, Median Market Cap, High Risk Count) · Sector combo chart (company count + avg Deal Score) · Valuation distribution donut

![Universe Overview](pbi/page1_universe_overview.png)

**Page 2 — Sector Deep Dive** *(drill-through from Page 1)*
Company detail table (Market Cap, EBITDA, EPS, Deal Score, Risk Flag) · Top 5 by Deal Score bar chart · Sector KPI cards (Avg P/E, Avg EPS)

![Sector Deep Dive](pbi/page2_sector_deep_dive.png)

**Page 3 — Opportunity Map**
Scatter plot (X = P/E ratio, Y = EPS, bubble size = Market Cap, colour = Risk Flag) · Slicers: Sector, Valuation Category, Market Cap range

![Opportunity Map](pbi/page3_opportunity_map.png)

---

## BPMN Process Diagrams

**AS-IS — Manual Screening Process**
Swimlanes: PE Fund Client | Financial Analyst | Deal Manager
Pain points annotated: no standardised criteria, 3–4 day cycle, no audit trail, static deliverable.

![AS-IS Process](bpmn/AS-IS_screenshot.png)

**TO-BE — AlphaScreen Automated Platform**
Swimlanes: PE Fund Client | Financial Analyst | System | Deal Manager
Exclusive gateway: Deal Score ≥ threshold → shortlist / archive. Client self-serve dashboard access as final step.

![TO-BE Process](bpmn/TO-BE_screenshot.png)

---

## Tech Stack

| Tool | Purpose |
|---|---|
| MySQL 8.x | Schema design, data loading, all 7 analytical queries |
| Power BI Desktop | Data modelling, DAX measures, 3-page dashboard |
| draw.io | AS-IS and TO-BE BPMN process diagrams |
| GitHub | Version control, portfolio hosting |

---

## How to Run

```bash
git clone https://github.com/triton1000/alphascreen-ma-screening
```

1. Open MySQL Workbench → run `sql/schema.sql` to create the `deallens_db` database and `companies` table
2. Right-click the `companies` table → Table Data Import Wizard → select `data/constituents-financials.csv`
3. Run `sql/queries.sql` to execute all 7 queries
4. Open `powerbi/AlphaScreen.pbix` in Power BI Desktop

---

## Repository Structure

alphascreen-ma-screening/
├── data/
│   └── constituents-financials.xlsx
│
├── sql/
│   ├── schema.sql
│   ├── queries.sql
│   ├── result_1.png
│   ├── result_2.png
│   ├── result_3.png
│   ├── result_4.png
│   ├── result_5.png
│   ├── result_6.png
│   └── result_7.png
│
├── pbi/
│   ├── AlphaScreen.pbix
│   ├── Opportunity Map.png
│   ├── Sector Deep Dive.png
│   └── Universe Overview.png
│
├── bpmn/
│   ├── AS-IS_Manual_Process.drawio
│   ├── AS-IS_screenshot.png
│   ├── TO-BE_Automated_Platform.drawio
│   └── TO-BE_screenshot.png
│
└── docs/
    ├── AlphaScreen_BRD.docx
    └── AlphaScreen_UAT.xlsx
