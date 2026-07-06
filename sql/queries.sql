-- Note: Rows with NULL values in EPS, EBITDA, or Price/Book are excluded from
-- Deal Score computation. These represent companies with incomplete SEC filings
-- in the source dataset and cannot be meaningfully scored.


-- Q1: Sector summary — avg EBITDA and company count
SELECT
    sector,
    COUNT(*)                  AS company_count,
    ROUND(AVG(ebitda), 2)     AS avg_ebitda
FROM companies
WHERE ebitda IS NOT NULL
GROUP BY sector
ORDER BY avg_ebitda DESC;

-- Q2: Top 3 companies by market cap per sector — DENSE_RANK inside CTE
WITH ranked AS (
    SELECT
        ticker,
        name,
        sector,
        market_cap,
        DENSE_RANK() OVER (
            PARTITION BY sector
            ORDER BY market_cap DESC
        ) AS mktcap_rank
    FROM companies
    WHERE market_cap IS NOT NULL
)
SELECT ticker, name, sector, market_cap, mktcap_rank
FROM ranked
WHERE mktcap_rank <= 3
ORDER BY sector, mktcap_rank;

-- Q3: Valuation Flag per Company
SELECT
    ticker,
    name,
    sector,
    pe_ratio,
    CASE
        WHEN pe_ratio IS NULL OR pe_ratio <= 0 THEN 'N/A'
        WHEN pe_ratio < 15                     THEN 'Undervalued'
        WHEN pe_ratio <= 25                    THEN 'Fair'
        ELSE                                        'Overvalued'
    END AS valuation_flag
FROM companies
ORDER BY sector, pe_ratio;

-- Q4: Composite Deal Score using min-max normalisation
WITH min_max_vals AS (
    SELECT 
        ticker,
        sector,
        name,
        eps,
        ebitda,
        price_book,
        MAX(eps) OVER() AS max_eps,
        MIN(eps) OVER() AS min_eps,
        MAX(ebitda) OVER() AS max_ebitda,
        MIN(ebitda) OVER() AS min_ebitda,
        MAX(price_book) OVER() AS max_pb,
        MIN(price_book) OVER() AS min_pb
    FROM companies
    WHERE eps IS NOT NULL 
      AND ebitda IS NOT NULL
      AND price_book IS NOT NULL
),
normalized AS (
    SELECT
        ticker,
        name,
        sector,
        ROUND((eps - min_eps) / NULLIF(max_eps - min_eps, 0), 4) AS eps_norm,
        ROUND((ebitda - min_ebitda) / NULLIF(max_ebitda - min_ebitda, 0), 4) AS ebitda_norm,
        ROUND((max_pb - price_book) / NULLIF(max_pb - min_pb, 0), 4) AS pb_norm
    FROM min_max_vals
)
SELECT
    ticker,
    name,
    sector,
    ROUND(((0.50 * eps_norm) + (0.25 * ebitda_norm) + (0.25 * pb_norm)) * 100, 4) AS deal_score
FROM normalized
ORDER BY deal_score DESC;

-- Q5: Deal Score with sector rank and vs-sector-average comparison
WITH min_max_vals AS (
    SELECT
        ticker,
        name,
        sector,
        eps,
        ebitda,
        price_book,
        MAX(eps) OVER() AS max_eps,
        MIN(eps) OVER() AS min_eps,
        MAX(ebitda) OVER() AS max_ebitda,
        MIN(ebitda) OVER() AS min_ebitda,
        MAX(price_book) OVER() AS max_pb,
        MIN(price_book) OVER() AS min_pb
    FROM companies
    WHERE eps IS NOT NULL
      AND ebitda IS NOT NULL
      AND price_book IS NOT NULL
),
scored AS (
    SELECT
        ticker,
        name,
        sector,
        ROUND(
            (
                0.50 * (eps - min_eps) / NULLIF(max_eps - min_eps, 0) +
                0.25 * (ebitda - min_ebitda) / NULLIF(max_ebitda - min_ebitda, 0) +
                0.25 * (max_pb - price_book) / NULLIF(max_pb - min_pb, 0)
            ) * 100,
            4
        ) AS deal_score
    FROM min_max_vals
),
sector_avg AS (
    SELECT
        sector,
        ROUND(AVG(deal_score), 4) AS sector_avg_score
    FROM scored
    GROUP BY sector
)
SELECT
    s.ticker,
    s.name,
    s.sector,
    s.deal_score,
    sa.sector_avg_score,
    ROUND(s.deal_score - sa.sector_avg_score, 4) AS diff,
    DENSE_RANK() OVER (
        PARTITION BY s.sector
        ORDER BY (s.deal_score - sa.sector_avg_score) DESC
    ) AS sector_rank
FROM scored s
JOIN sector_avg sa
    ON s.sector = sa.sector
ORDER BY s.sector, sector_rank;

-- Q6: Risk classification per company
SELECT
    ticker,
    name,
    sector,
    eps,
    ebitda,
    price_book,
    CASE
        WHEN eps IS NULL
          OR ebitda IS NULL
          OR price_book IS NULL
          OR eps < 0
          OR ebitda < 0
          OR price_book > 8
        THEN 'High Risk'

        WHEN eps BETWEEN 0 AND 2
          OR price_book BETWEEN 5 AND 8
        THEN 'Medium Risk'

        ELSE 'Low Risk'
    END AS risk_flag
FROM companies
ORDER BY sector;

-- Q7: Final acquisition shortlist — top 10 by Deal Score
WITH minmax_vals AS (
    SELECT
        ticker,
        name,
        sector,
        market_cap,
        eps,
        ebitda,
        price_book,
        MIN(eps)        OVER () AS min_eps,
        MAX(eps)        OVER () AS max_eps,
        MIN(ebitda)     OVER () AS min_ebitda,
        MAX(ebitda)     OVER () AS max_ebitda,
        MIN(price_book) OVER () AS min_pb,
        MAX(price_book) OVER () AS max_pb
    FROM companies
    WHERE eps        IS NOT NULL
      AND ebitda     IS NOT NULL
      AND price_book IS NOT NULL
)
SELECT
    ticker,
    name,
    sector,
    market_cap,
    ROUND(
        (
        (0.4 * (eps        - min_eps)      / NULLIF(max_eps      - min_eps,      0))
      + (0.3 * (ebitda     - min_ebitda)   / NULLIF(max_ebitda   - min_ebitda,   0))
      + (0.3 * (price_book - min_pb)       / NULLIF(max_pb       - min_pb,       0))
      )*100
    , 4) AS deal_score
FROM minmax_vals
ORDER BY deal_score DESC
LIMIT 10;