-- =========================================================
-- 4주차 2회차 데모용 model input table 생성
-- =========================================================
-- 목적
-- - 1회차에서 만든 "롱런 여부 label" 흐름을 모델 입력 테이블로 연결한다.
-- - safe table은 첫 Top10 진입 주차에 알 수 있는 feature만 둔다.
-- - leakage table은 성능 부풀림을 비교하기 위해 label과 직접 연결된 사후 지표를 함께 둔다.
--
-- Grain
-- - title_clean 1행
-- - 한 행은 "Top10에 진입한 콘텐츠 하나"를 의미한다.
-- =========================================================

DROP TABLE IF EXISTS netflix_model_input_safe;
DROP TABLE IF EXISTS netflix_model_input_leakage;

CREATE TABLE netflix_model_input_safe AS
-- weekly_source
-- - raw Top10 성과 테이블에서 모델 입력에 필요한 주차별 성과 컬럼만 고른다.
-- - 아직 같은 show_title이 같은 주차에 여러 시즌/성과 행으로 남아 있을 수 있다.
WITH weekly_source AS (
    SELECT
        week AS week_date,
        LOWER(TRIM(show_title)) AS title_clean,
        show_title,
        weekly_rank AS weekly_rank_num,
        weekly_hours_viewed AS weekly_hours_viewed_num,
        cumulative_weeks_in_top_10 AS cumulative_weeks_in_top_10_num
    FROM netflix_all_weeks_global
    WHERE show_title IS NOT NULL
      AND show_title NOT LIKE '%�%'
      AND weekly_rank IS NOT NULL
      AND weekly_hours_viewed IS NOT NULL
      AND cumulative_weeks_in_top_10 IS NOT NULL
),
-- content_week_base
-- - 모델링 기준 grain으로 가기 전, week_date + title_clean 단위로 성과를 접는다.
-- - 같은 콘텐츠의 여러 시즌이 같은 주차 Top10에 동시에 있을 수 있으므로 여기서 먼저 요약한다.
content_week_base AS (
    SELECT
        week_date,
        title_clean,
        MIN(show_title) AS show_title,
        MIN(weekly_rank_num) AS weekly_rank_num,
        SUM(DISTINCT weekly_hours_viewed_num) AS weekly_hours_viewed_num,
        MAX(cumulative_weeks_in_top_10_num) AS cumulative_weeks_in_top_10_num
    FROM weekly_source
    GROUP BY week_date, title_clean
),
-- first_week
-- - 예측 시점을 "Top10 첫 진입 주차"로 고정하기 위한 CTE다.
-- - safe feature는 이 시점에 알 수 있는 정보만 사용한다.
first_week AS (
    SELECT
        week_date,
        title_clean,
        show_title,
        weekly_rank_num,
        weekly_hours_viewed_num
    FROM (
        SELECT
            content_week_base.*,
            ROW_NUMBER() OVER (
                PARTITION BY title_clean
                ORDER BY week_date, weekly_rank_num
            ) AS row_num
        FROM content_week_base
    ) AS ranked
    WHERE row_num = 1
),
-- content_summary
-- - 전체 Top10 기간을 다 본 뒤에야 알 수 있는 콘텐츠별 성과 요약이다.
-- - 여기서는 long_run_flag label을 만들기 위해서만 사용한다.
content_summary AS (
    SELECT
        title_clean,
        COUNT(DISTINCT week_date) AS weeks_in_top10,
        MIN(weekly_rank_num) AS best_rank,
        MAX(cumulative_weeks_in_top_10_num) AS max_cumulative_weeks
    FROM content_week_base
    GROUP BY title_clean
),
-- title_features
-- - Netflix 메타데이터에서 콘텐츠 유형과 대표 장르를 가져온다.
-- - 대표 장르는 listed_in의 첫 번째 장르만 사용해 데모용 feature를 단순화한다.
title_features AS (
    SELECT
        LOWER(TRIM(title)) AS title_clean,
        MIN(NULLIF(type, 'nan')) AS type_clean,
        MIN(NULLIF(TRIM(SPLIT_PART(listed_in, ',', 1)), '')) AS primary_genre
    FROM netflix_titles
    WHERE title IS NOT NULL
      AND title NOT LIKE '%�%'
      AND title NOT LIKE '%ÿ%'
      AND title NOT LIKE '%ã%'
    GROUP BY LOWER(TRIM(title))
)
SELECT
    fw.title_clean,
    fw.show_title,
    tf.type_clean,
    tf.primary_genre,
    fw.week_date AS first_week_date,
    CASE
        WHEN EXTRACT(MONTH FROM fw.week_date) IN (3, 4, 5) THEN 'spring'
        WHEN EXTRACT(MONTH FROM fw.week_date) IN (6, 7, 8) THEN 'summer'
        WHEN EXTRACT(MONTH FROM fw.week_date) IN (9, 10, 11) THEN 'fall'
        ELSE 'winter'
    END AS first_season,
    EXTRACT(MONTH FROM fw.week_date)::int AS first_month_num,
    fw.weekly_rank_num AS first_week_rank,
    fw.weekly_hours_viewed_num AS first_week_hours_viewed,
    CASE
        WHEN fw.weekly_rank_num <= 3 THEN 'top_3'
        WHEN fw.weekly_rank_num <= 7 THEN 'rank_4_7'
        ELSE 'rank_8_10'
    END AS initial_rank_bucket,
    CASE
        WHEN fw.weekly_hours_viewed_num >= 50000000 THEN 'high'
        WHEN fw.weekly_hours_viewed_num >= 10000000 THEN 'medium'
        ELSE 'low'
    END AS initial_hours_bucket,
    CASE
        WHEN cs.max_cumulative_weeks >= 4 THEN 1
        ELSE 0
    END AS long_run_flag
FROM first_week AS fw
JOIN content_summary AS cs
    ON fw.title_clean = cs.title_clean
JOIN title_features AS tf
    ON fw.title_clean = tf.title_clean
WHERE tf.type_clean IS NOT NULL
  AND tf.primary_genre IS NOT NULL;

CREATE TABLE netflix_model_input_leakage AS
-- leakage table은 safe table에 사후 성과 요약을 붙인 비교용 테이블이다.
-- 실제 예측용으로 쓰기보다, leakage가 성능을 얼마나 부풀릴 수 있는지 보여주는 데 사용한다.
WITH weekly_source AS (
    SELECT
        week AS week_date,
        LOWER(TRIM(show_title)) AS title_clean,
        show_title,
        weekly_rank AS weekly_rank_num,
        weekly_hours_viewed AS weekly_hours_viewed_num,
        cumulative_weeks_in_top_10 AS cumulative_weeks_in_top_10_num
    FROM netflix_all_weeks_global
    WHERE show_title IS NOT NULL
      AND show_title NOT LIKE '%�%'
      AND weekly_rank IS NOT NULL
      AND weekly_hours_viewed IS NOT NULL
      AND cumulative_weeks_in_top_10 IS NOT NULL
),
content_week_base AS (
    SELECT
        week_date,
        title_clean,
        MIN(show_title) AS show_title,
        MIN(weekly_rank_num) AS weekly_rank_num,
        SUM(DISTINCT weekly_hours_viewed_num) AS weekly_hours_viewed_num,
        MAX(cumulative_weeks_in_top_10_num) AS cumulative_weeks_in_top_10_num
    FROM weekly_source
    GROUP BY week_date, title_clean
),
content_summary AS (
    SELECT
        title_clean,
        COUNT(DISTINCT week_date) AS weeks_in_top10,
        MIN(weekly_rank_num) AS best_rank,
        MAX(cumulative_weeks_in_top_10_num) AS max_cumulative_weeks
    FROM content_week_base
    GROUP BY title_clean
)
SELECT
    safe.*,
    cs.weeks_in_top10,
    cs.best_rank,
    cs.max_cumulative_weeks
FROM netflix_model_input_safe AS safe
JOIN content_summary AS cs
    ON safe.title_clean = cs.title_clean;

-- =========================================================
-- 생성 결과 확인
-- =========================================================

SELECT
    'safe' AS table_name,
    COUNT(*) AS row_count,
    COUNT(DISTINCT title_clean) AS title_count,
    COUNT(*) - COUNT(DISTINCT title_clean) AS duplicate_title_rows
FROM netflix_model_input_safe
UNION ALL
SELECT
    'leakage' AS table_name,
    COUNT(*) AS row_count,
    COUNT(DISTINCT title_clean) AS title_count,
    COUNT(*) - COUNT(DISTINCT title_clean) AS duplicate_title_rows
FROM netflix_model_input_leakage;

SELECT
    long_run_flag,
    COUNT(*) AS content_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS content_ratio_pct
FROM netflix_model_input_safe
GROUP BY long_run_flag
ORDER BY long_run_flag;

SELECT
    *
FROM netflix_model_input_safe
ORDER BY first_week_date DESC, first_week_rank, title_clean
LIMIT 20;
