/*
Pharma & Clinical Trials Analytics
SQL Analysis

Data source: ClinicalTrials.gov
Analytical database: PostgreSQL
Schema: pharma_trials

This file contains the main SQL queries used to validate and
extend the clinical trial analysis performed in Python.
*/


-- ============================================================
-- 1. Clinical Trial Portfolio by Sponsor
-- ============================================================

SELECT
    sponsor_category,
    COUNT(*) AS studies,
    ROUND(
        COUNT(*) * 100.0 /
        SUM(COUNT(*)) OVER (),
        2
    ) AS percentage
FROM pharma_trials.clinical_trials
GROUP BY sponsor_category
ORDER BY studies DESC;


-- ============================================================
-- 2. Clinical Phase Distribution by Sponsor
-- ============================================================

WITH phase_counts AS (
    SELECT
        sponsor_category,
        phase_category,
        COUNT(*) AS studies
    FROM pharma_trials.clinical_trials
    WHERE phase_category IN (
        'Early Phase 1',
        'Phase 1',
        'Phase 2',
        'Phase 3',
        'Phase 4'
    )
    GROUP BY
        sponsor_category,
        phase_category
)

SELECT
    sponsor_category,
    phase_category,
    studies,
    ROUND(
        studies * 100.0 /
        SUM(studies) OVER (
            PARTITION BY sponsor_category
        ),
        2
    ) AS percentage_within_sponsor
FROM phase_counts
ORDER BY
    CASE sponsor_category
        WHEN 'Industry' THEN 1
        WHEN 'Government' THEN 2
        WHEN 'Other' THEN 3
    END,
    CASE phase_category
        WHEN 'Early Phase 1' THEN 1
        WHEN 'Phase 1' THEN 2
        WHEN 'Phase 2' THEN 3
        WHEN 'Phase 3' THEN 4
        WHEN 'Phase 4' THEN 5
    END;


-- ============================================================
-- 3. Known Final Outcomes by Sponsor
-- ============================================================

SELECT
    sponsor_category,

    COUNT(*) FILTER (
        WHERE status_group = 'Completed'
    ) AS completed_trials,

    COUNT(*) FILTER (
        WHERE status_group = 'Discontinued'
    ) AS discontinued_trials,

    ROUND(
        100.0 *
        COUNT(*) FILTER (
            WHERE status_group = 'Completed'
        ) / COUNT(*),
        2
    ) AS completion_rate,

    ROUND(
        100.0 *
        COUNT(*) FILTER (
            WHERE status_group = 'Discontinued'
        ) / COUNT(*),
        2
    ) AS discontinuation_rate

FROM pharma_trials.clinical_trials

WHERE status_group IN (
    'Completed',
    'Discontinued'
)

GROUP BY sponsor_category
ORDER BY completion_rate DESC;


-- ============================================================
-- 4. Enrollment and Duration by Clinical Phase
-- ============================================================

SELECT
    phase_category,

    COUNT(*) FILTER (
        WHERE enrollment_clean > 0
    ) AS studies_with_enrollment,

    ROUND(
        AVG(enrollment_clean) FILTER (
            WHERE enrollment_clean > 0
        ),
        1
    ) AS mean_enrollment,

    ROUND(
        (
            PERCENTILE_CONT(0.5)
            WITHIN GROUP (
                ORDER BY enrollment_clean
            )
            FILTER (
                WHERE enrollment_clean > 0
            )
        )::numeric,
        1
    ) AS median_enrollment,

    COUNT(observed_duration_years)
        AS studies_with_duration,

    ROUND(
        (
            PERCENTILE_CONT(0.5)
            WITHIN GROUP (
                ORDER BY observed_duration_years
            )
            FILTER (
                WHERE observed_duration_years IS NOT NULL
            )
        )::numeric,
        2
    ) AS median_duration_years

FROM pharma_trials.clinical_trials

WHERE
    status_group = 'Completed'
    AND phase_category IN (
        'Early Phase 1',
        'Phase 1',
        'Phase 2',
        'Phase 3',
        'Phase 4'
    )

GROUP BY phase_category

ORDER BY
    CASE phase_category
        WHEN 'Early Phase 1' THEN 1
        WHEN 'Phase 1' THEN 2
        WHEN 'Phase 2' THEN 3
        WHEN 'Phase 3' THEN 4
        WHEN 'Phase 4' THEN 5
    END;


-- ============================================================
-- 5. Leading Therapeutic Areas
-- ============================================================

SELECT
    areas.therapeutic_area,

    COUNT(
        DISTINCT trials.nct_id
    ) AS trials,

    ROUND(
        COUNT(DISTINCT trials.nct_id) * 100.0 /
        (
            SELECT COUNT(*)
            FROM pharma_trials.clinical_trials
        ),
        2
    ) AS percentage_of_all_trials

FROM pharma_trials.trial_therapeutic_areas AS areas

INNER JOIN pharma_trials.clinical_trials AS trials
    ON areas.nct_id = trials.nct_id

WHERE areas.therapeutic_area NOT IN (
    'Other / Unclassified',
    'No Condition Information'
)

GROUP BY areas.therapeutic_area
ORDER BY trials DESC
LIMIT 10;


-- ============================================================
-- 6. Geographic Scope by Sponsor
-- ============================================================

SELECT
    sponsor_category,

    COUNT(*) FILTER (
        WHERE geographic_scope = 'Single-country'
    ) AS single_country_trials,

    COUNT(*) FILTER (
        WHERE geographic_scope = 'Multinational'
    ) AS multinational_trials,

    ROUND(
        100.0 *
        COUNT(*) FILTER (
            WHERE geographic_scope = 'Single-country'
        ) / COUNT(*),
        2
    ) AS single_country_percentage,

    ROUND(
        100.0 *
        COUNT(*) FILTER (
            WHERE geographic_scope = 'Multinational'
        ) / COUNT(*),
        2
    ) AS multinational_percentage

FROM pharma_trials.clinical_trials

WHERE geographic_scope IN (
    'Single-country',
    'Multinational'
)

GROUP BY sponsor_category
ORDER BY multinational_percentage DESC;
