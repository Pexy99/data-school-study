-- =========================================================
-- 목적
-- 이번 실습의 목표는 "새 문법을 많이 쓰는 것"이 아니라,
-- 프로젝트 데이터에서 SQL로 feature engineering을 하는 흐름을 익히는 것이다.
--
-- 1) raw -> intermediate -> business 흐름
--    - 이미 확보한 데이터를 바로 최종 분석에 쓰지 않고,
--      중간 단계에서 feature를 만든다.
--
-- 2) SQL feature engineering
--    - CASE WHEN, GROUP BY, WITH, window function을 사용해
--      분석/모델링에 쓸 컬럼을 만든다.
--
-- 사용할 테이블
-- - netflix_all_weeks_global  : 주차별 글로벌 Top10 성과 raw 테이블
-- - netflix_titles            : 콘텐츠 유형, 장르 등 메타데이터 raw 테이블
-- - netflix_mart_global       : Top10 성과와 콘텐츠 메타데이터를 조인/정리한 1차 분석용 테이블
-- - netflix_mart_clean        : 이번 실습에서 임시로 만드는 정제 테이블
--
-- 참고
-- - CSV 파일명은 mart_global_final.csv이지만,
--   PostgreSQL 셋업 후 테이블명은 netflix_mart_global이다.
--
-- 주요 컬럼
-- - week_date                          : 주차 기준 날짜
-- - season                             : 봄/여름/가을/겨울
-- - title_clean                        : 표준화된 콘텐츠 제목
-- - show_title                         : 원본 콘텐츠 제목
-- - weekly_rank_num                    : 주간 인기 순위
-- - weekly_hours_viewed_num            : 주간 시청 시간
-- - cumulative_weeks_in_top_10_num     : Top10 누적 유지 주
-- - type_clean                         : Movie / TV Show
-- - genre                              : 콘텐츠 장르
--
-- 이 파일의 흐름
-- 0. 분석용 테이블 구조 확인과 정제 테이블 만들기
-- 1. grain 확인: 한 행이 무엇을 의미하는지 보기
-- 2. Q1: 글로벌 Top10에 자주 등장하는 장르 찾기
-- 3. Q2: 계절별 선호 장르 찾기
-- 4. Q3: 시즌별 급상승 장르 찾기
-- 5. Q4용 콘텐츠-주차 intermediate 만들기
-- 6. 콘텐츠별 롱런 여부 label 만들기
-- =========================================================


-- =========================================================
-- mart 데이터가 만들어진 배경
--
-- netflix_titles 같은 원본 메타데이터에서는 장르가 보통 한 컬럼 안에
-- 'TV Dramas, International TV Shows'처럼 콤마로 묶여 있다.
--
-- 하지만 이번 세션의 핵심 질문은 "장르별로 Top10에 얼마나 자주 등장했는가?"이다.
-- 이 질문에 답하려면 장르를 하나씩 분리해서 GROUP BY genre를 할 수 있어야 한다.
--
-- 그래서 netflix_mart_global은 장르를 행으로 펼친 long format에 가깝다.
-- 예를 들어 The Crown이 장르 3개를 가지면 같은 주차에도 3행으로 보일 수 있다.
--
-- 즉 이 테이블의 실질적인 grain은 아래에 가깝다.
-- -> week_date + title_clean + genre
--
-- 장점:
-- -> GROUP BY genre로 장르별 분석이 쉬워진다.
--
-- 주의:
-- -> 콘텐츠 단위로 COUNT/SUM을 할 때는 장르 수만큼 중복 집계될 수 있다.
--    그래서 COUNT(*)와 COUNT(DISTINCT title_clean)의 의미를 구분해야 한다.
-- =========================================================



-- =========================================================
-- [예제 0]
-- 무엇을 하려는가?
-- -> 이번 세션에서 주로 사용할 분석용 테이블을 먼저 확인한다.
--
-- 여기서 볼 점
-- -> 날짜, 제목, 순위, 시청 시간, 누적 유지 주, 유형, 장르가 있는지
-- -> 이미 raw를 한 번 정리한 분석용 테이블이라는 점
-- =========================================================
SELECT
    week_date,
    season,
    title_clean,
    show_title,
    weekly_rank_num,
    weekly_hours_viewed_num,
    cumulative_weeks_in_top_10_num,
    type_clean,
    genre
FROM netflix_mart_global
LIMIT 20;

-- 확인용: 분석용 테이블에도 품질 이슈가 남아 있는지 확인한다.
-- genre/type_clean의 'nan'은 SQL NULL이 아니라 문자열이다.
-- 제목의 '�'는 원천 데이터 또는 이전 정제 과정에서 생긴 깨진 문자로 보고,
-- 이번 실습의 분석 대상에서는 제외한다.
SELECT
    COUNT(*) AS total_rows,
    COUNT(*) FILTER (WHERE genre = 'nan') AS genre_nan_rows,
    COUNT(*) FILTER (WHERE type_clean = 'nan') AS type_nan_rows,
    COUNT(*) FILTER (
        WHERE title_clean LIKE '%�%'
           OR show_title LIKE '%�%'
    ) AS broken_title_rows
FROM netflix_mart_global;

-- 이번 실습에서는 분석을 방해하는 값들을 제외한 임시 정제 테이블을 만든다.
-- 원본 netflix_mart_global은 그대로 두고, 이후 예제는 netflix_mart_clean을 사용한다.
DROP TABLE IF EXISTS netflix_mart_clean;

CREATE TEMP TABLE netflix_mart_clean AS
SELECT
    week_date,
    month_num,
    season,
    title_clean,
    show_title,
    weekly_rank_num,
    weekly_hours_viewed_num,
    cumulative_weeks_in_top_10_num,
    -- TODO: 'nan' 문자열을 분석에서 제외할 수 있는 값으로 바꾼다.
    TODO AS type_clean,
    TODO AS genre
FROM netflix_mart_global
WHERE title_clean IS NOT NULL
  AND show_title IS NOT NULL
  AND title_clean NOT LIKE '%�%'
  AND show_title NOT LIKE '%�%'
  -- TODO: type_clean, genre의 'nan' 문자열을 제외한다.
  AND TODO IS NOT NULL
  AND TODO IS NOT NULL;

-- 확인용: 정제 후 분석 대상 행이 얼마나 남았는지 본다.
SELECT
    COUNT(*) AS clean_rows,
    -- TODO: 중복을 제외한 고유 콘텐츠 수를 센다.
    TODO AS clean_title_count,
    -- TODO: 중복을 제외한 고유 장르 수를 센다.
    TODO AS clean_genre_count
FROM netflix_mart_clean;



-- =========================================================
-- [예제 1]
-- 무엇을 하려는가?
-- -> 이 테이블의 grain, 즉 "한 행이 무엇을 의미하는지" 확인한다.
--
-- 왜 이 예제를 먼저 하나?
-- -> feature engineering을 하기 전에 grain을 잘못 이해하면,
--    GROUP BY나 window function 결과를 잘못 해석하기 쉽다.
--
-- 여기서 배우는 핵심
-- -> 이 테이블은 주차별 콘텐츠 성과에 장르가 붙은 형태로 볼 수 있다.
-- -> 같은 콘텐츠와 같은 주차라도 장르가 여러 개면 여러 행으로 보일 수 있다.
-- -> 이것은 제거해야 할 중복이라기보다, 장르 분석을 위해 펼친 long format의 결과다.
-- =========================================================
SELECT
    week_date,
    title_clean,
    show_title,
    genre,
    weekly_rank_num,
    weekly_hours_viewed_num
FROM netflix_mart_clean
ORDER BY week_date DESC, weekly_rank_num, title_clean, genre
LIMIT 30;

-- 확인용: 같은 주차 + 같은 콘텐츠가 장르 때문에 여러 행으로 보일 수 있는지 본다.
-- row_count가 3이고 genre_count가 3이면, 같은 콘텐츠가 장르 3개로 펼쳐졌다는 뜻이다.
-- 단, 일부 TV Show는 같은 주차에 여러 season_title이 동시에 Top10에 들어올 수 있다.
-- 예: Stranger Things가 한 주에 시즌 2/3/4까지 같이 순위권이면
--     성과 행 4개 * 장르 3개 = row_count 12, genre_count 3으로 보일 수 있다.
SELECT
    week_date,
    title_clean,
    COUNT(*) AS row_count,
    -- TODO: 같은 콘텐츠-주차에 붙은 고유 장르 수를 센다.
    TODO AS genre_count
FROM netflix_mart_clean
GROUP BY week_date, title_clean
HAVING COUNT(*) > 1
ORDER BY row_count DESC, week_date DESC
LIMIT 20;

-- 완성되면 대략 이런 결과를 기대한다:
-- week_date  | title_clean         | row_count | genre_count
-- 2023-12-17 | example title       | 3         | 3



-- =========================================================
-- [예제 2]
-- 무엇을 하려는가?
-- -> Q1. 글로벌 Top10에 자주 등장하는 콘텐츠의 장르를 찾는다.
--
-- 왜 이 예제를 하나?
-- -> "어떤 장르가 글로벌에서 잘 먹히는가?"는
--    GROUP BY로 바로 답하기 좋은 설명형 분석 질문이다.
--
-- 여기서 배우는 핵심
-- -> long format 덕분에 GROUP BY genre가 쉬워졌다.
-- -> 대신 COUNT(*)는 고유 콘텐츠 수가 아니라 장르별 Top10 등장 행 수다.
-- -> COUNT(DISTINCT title_clean)는 장르별 고유 콘텐츠 수를 보여준다.
-- =========================================================
SELECT
    genre,
    -- TODO: 장르별 Top10 등장 행 수를 센다.
    TODO AS top10_row_count,
    -- TODO: 장르별 고유 콘텐츠 수를 센다.
    TODO AS title_count,
    -- TODO: 평균 순위를 소수점 둘째 자리까지 반올림한다.
    TODO AS avg_rank,
    -- TODO: 평균 시청 시간을 정수로 반올림한다.
    TODO AS avg_hours_viewed
FROM netflix_mart_clean
-- TODO: genre 기준으로 묶는다.
GROUP BY TODO
ORDER BY top10_row_count DESC, avg_rank
LIMIT 20;

-- 완성되면 대략 이런 결과를 기대한다:
-- genre  | top10_row_count | title_count | avg_rank | avg_hours_viewed
-- Drama  | 1200            | 320         | 5.42     | 15000000



-- =========================================================
-- [예제 3]
-- 무엇을 하려는가?
-- -> Q2. 계절별로 선호하는 장르를 찾는다.
--
-- 왜 이 예제를 하나?
-- -> "계절별로 어떤 장르가 많이 등장하고 성과가 좋은가?"는
--    season + genre 단위 business table로 답하기 좋다.
--
-- 여기서 배우는 핵심
-- -> 한 행은 season + genre다.
-- -> season 안에서 장르별 등장 횟수와 성과를 비교한다.
-- -> 장르 순위는 Top10 등장 행 수가 많은 순서로 매기고,
--    동률이면 평균 순위가 좋은 장르를 먼저 둔다.
-- -> weekly_rank_num은 숫자가 작을수록 좋은 순위다.
-- =========================================================
SELECT
    season,
    genre,
    -- 이 계절에 해당 장르가 Top10 행에 얼마나 자주 등장했는지 센다.
    COUNT(*) AS top10_row_count,
    -- TODO: season + genre 안에서 고유 콘텐츠 수를 센다.
    TODO AS title_count,
    ROUND(AVG(weekly_rank_num), 2) AS avg_rank,
    ROUND(AVG(weekly_hours_viewed_num), 0) AS avg_hours_viewed,
    -- TODO: 계절 안에서 Top10 등장 행 수가 많은 장르부터 순위를 매긴다.
    --       동률이면 평균 순위가 좋은 장르를 먼저 둔다.
    TODO AS genre_rank_in_season
FROM netflix_mart_clean
GROUP BY season, genre
ORDER BY season, genre_rank_in_season
LIMIT 40;

-- 완성되면 대략 이런 결과를 기대한다:
-- season | genre     | top10_row_count | title_count | avg_rank | avg_hours_viewed | genre_rank_in_season
-- fall   | TV Dramas | 171             | 39          | 5.27     | 38674269         | 1



-- =========================================================
-- [예제 4]
-- 무엇을 하려는가?
-- -> Q3. 이전 시즌 대비 Top10 등장 횟수가 많이 증가한 장르를 찾는다.
--
-- 왜 이 예제를 하나?
-- -> "급상승"은 단순히 많이 등장한 장르가 아니라,
--    이전 기간보다 얼마나 증가했는지를 봐야 하기 때문이다.
-- -> 여기서는 급상승을
--    현재 시즌 top10_row_count - 이전 시즌 top10_row_count로 정의한다.
--
-- 여기서 배우는 핵심
-- -> 먼저 year + season + genre 단위로 집계한 뒤,
--    같은 장르의 이전 시즌 값을 가져온다.
-- -> season만 쓰면 여러 해가 섞이므로 year_num과 season_order가 필요하다.
-- =========================================================
-- 1단계 확인: year + season + genre 단위로 집계됐는지 본다.
WITH season_genre_summary AS (
    SELECT
        EXTRACT(YEAR FROM week_date)::int AS year_num,
        season,
        CASE season
            WHEN 'spring' THEN 1
            WHEN 'summer' THEN 2
            WHEN 'fall' THEN 3
            WHEN 'winter' THEN 4
        END AS season_order,
        genre,
        -- TODO: 연도-시즌-장르별 Top10 등장 행 수를 센다.
        TODO AS top10_row_count,
        -- TODO: 연도-시즌-장르별 고유 콘텐츠 수를 센다.
        TODO AS title_count,
        ROUND(AVG(weekly_rank_num), 2) AS avg_rank
    FROM netflix_mart_clean
    GROUP BY year_num, season, season_order, genre
)
SELECT
    year_num,
    season,
    genre,
    top10_row_count,
    title_count,
    avg_rank
FROM season_genre_summary
ORDER BY year_num, season_order, top10_row_count DESC
LIMIT 30;

-- 2단계 확인: 같은 장르의 이전 시즌 등장 횟수가 붙었는지 본다.
WITH season_genre_summary AS (
    SELECT
        EXTRACT(YEAR FROM week_date)::int AS year_num,
        season,
        CASE season
            WHEN 'spring' THEN 1
            WHEN 'summer' THEN 2
            WHEN 'fall' THEN 3
            WHEN 'winter' THEN 4
        END AS season_order,
        genre,
        COUNT(*) AS top10_row_count,
        COUNT(DISTINCT title_clean) AS title_count,
        ROUND(AVG(weekly_rank_num), 2) AS avg_rank
    FROM netflix_mart_clean
    GROUP BY year_num, season, season_order, genre
),
season_genre_change AS (
    SELECT
        year_num,
        season,
        season_order,
        genre,
        top10_row_count,
        title_count,
        avg_rank,
        -- TODO: 같은 장르 안에서 시간순 직전 시즌의 Top10 등장 행 수를 가져온다.
        TODO AS prev_top10_row_count
    FROM season_genre_summary
)
SELECT
    year_num,
    season,
    genre,
    top10_row_count,
    prev_top10_row_count,
    title_count,
    avg_rank
FROM season_genre_change
ORDER BY genre, year_num, season_order
LIMIT 30;

-- 3단계: 이전 시즌 대비 증가량을 계산해서 급상승 장르를 찾는다.
WITH season_genre_summary AS (
    SELECT
        EXTRACT(YEAR FROM week_date)::int AS year_num,
        season,
        CASE season
            WHEN 'spring' THEN 1
            WHEN 'summer' THEN 2
            WHEN 'fall' THEN 3
            WHEN 'winter' THEN 4
        END AS season_order,
        genre,
        COUNT(*) AS top10_row_count,
        COUNT(DISTINCT title_clean) AS title_count,
        ROUND(AVG(weekly_rank_num), 2) AS avg_rank
    FROM netflix_mart_clean
    GROUP BY year_num, season, season_order, genre
),
season_genre_change AS (
    SELECT
        year_num,
        season,
        season_order,
        genre,
        top10_row_count,
        title_count,
        avg_rank,
        LAG(top10_row_count) OVER (
            PARTITION BY genre
            ORDER BY year_num, season_order
        ) AS prev_top10_row_count
    FROM season_genre_summary
)
SELECT
    year_num,
    season,
    genre,
    top10_row_count,
    prev_top10_row_count,
    -- TODO: 현재 시즌 등장 행 수 - 이전 시즌 등장 행 수를 계산한다.
    --       이 값이 클수록 이전 시즌 대비 더 크게 증가한 장르다.
    TODO AS count_change,
    title_count,
    avg_rank
FROM season_genre_change
WHERE prev_top10_row_count IS NOT NULL
-- 증가량이 큰 장르부터 보여주고, 증가량이 같으면 현재 등장 행 수가 많은 장르를 먼저 둔다.
ORDER BY count_change DESC, top10_row_count DESC
LIMIT 30;

-- 완성되면 대략 이런 결과를 기대한다:
-- year_num | season | genre     | top10_row_count | prev_top10_row_count | count_change
-- 2022     | summer | TV Dramas | 80              | 45                   | 35



-- =========================================================
-- [예제 5]
-- 무엇을 하려는가?
-- -> Q4를 위해 raw 성과 테이블과 메타데이터 테이블을 조인해서
--    콘텐츠-주차 단위 중간 테이블을 새로 만든다.
--
-- 왜 이 예제가 중요한가?
-- -> netflix_mart_clean은 이미 장르 분석을 위해 펼쳐진 결과물이다.
-- -> Q4 롱런 비교처럼 콘텐츠 성과 흐름이 핵심인 질문은
--    mart를 다시 접기보다 원천 성과 테이블에서 새 intermediate를 만드는 편이 맞다.
--
-- 여기서 배우는 핵심
-- -> 질문마다 맞는 grain을 먼저 정하고,
--    그 grain에 맞게 raw/metadata를 조인해서 intermediate table을 만든다.
--
-- 기대하는 테이블 형태
-- -> grain: week_date + title_clean
-- -> 한 행은 "한 콘텐츠가 특정 주차에 Top10에 등장한 기록"이다.
-- -> 6번에서는 이 테이블을 title_clean 단위로 요약해서 롱런 여부를 만든다.
-- =========================================================
DROP TABLE IF EXISTS netflix_content_week_clean;

CREATE TEMP TABLE netflix_content_week_clean AS
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
title_features AS (
    SELECT
        LOWER(TRIM(title)) AS title_clean,
        MIN(NULLIF(type, 'nan')) AS type_clean
    FROM netflix_titles
    WHERE title IS NOT NULL
      AND title NOT LIKE '%�%'
      AND title NOT LIKE '%ÿ%'
      AND title NOT LIKE '%ã%'
    GROUP BY LOWER(TRIM(title))
)
SELECT
    cwb.week_date,
    cwb.title_clean,
    cwb.show_title,
    tf.type_clean,
    cwb.weekly_rank_num,
    cwb.weekly_hours_viewed_num,
    cwb.cumulative_weeks_in_top_10_num
FROM content_week_base AS cwb
JOIN title_features AS tf
    ON cwb.title_clean = tf.title_clean;

-- 확인용: 콘텐츠-주차 단위로 중복이 사라졌는지 확인한다.
-- duplicate_content_week_rows가 0이면 week_date + title_clean grain으로 볼 수 있다.
-- 같은 콘텐츠가 같은 주에 여러 성과 행을 가질 수 있어서 raw 성과를 먼저 요약했다.
SELECT
    COUNT(*) AS content_week_rows,
    COUNT(DISTINCT (week_date, title_clean)) AS distinct_content_week_rows,
    COUNT(*) - COUNT(DISTINCT (week_date, title_clean)) AS duplicate_content_week_rows
FROM netflix_content_week_clean;

-- 확인용: raw 성과 테이블에서 온 content_week와
-- netflix_titles에서 온 메타데이터와 조인된 분석 대상 행 수를 본다.
SELECT
    COUNT(*) AS content_week_rows,
    COUNT(*) FILTER (WHERE type_clean IS NOT NULL) AS matched_type_rows
FROM netflix_content_week_clean;

-- 확인용: Q4에서 사용할 콘텐츠-주차 intermediate가 어떻게 생겼는지 본다.
SELECT
    week_date,
    title_clean,
    show_title,
    type_clean,
    weekly_rank_num,
    weekly_hours_viewed_num,
    cumulative_weeks_in_top_10_num
FROM netflix_content_week_clean
ORDER BY week_date DESC, weekly_rank_num, title_clean
LIMIT 30;



-- =========================================================
-- [예제 6]
-- 무엇을 하려는가?
-- -> 콘텐츠별 롱런 여부 label을 만든다.
--
-- 왜 이 예제를 하나?
-- -> 어떤 요인이 롱런과 관련 있는지 보려면
--    먼저 롱런 여부를 0/1로 정의해야 한다.
-- -> 여기서는 Top10에 4주 이상 머문 콘텐츠를 롱런 콘텐츠로 본다.
-- -> long_run_flag는 이후 요인 분석이나 모델링에서 사용할 target/label 후보가 된다.
--
-- 여기서 배우는 핵심
-- -> content-week 행을 title_clean 단위로 요약해서 label을 만든다.
-- -> weeks_in_top10, best_rank, max_cumulative_weeks는 콘텐츠별 성과 요약 지표다.
-- -> 이번 예제는 모델을 만드는 단계가 아니라,
--    모델링 전에 필요한 content-level label table을 만드는 단계다.
--
-- 이 결과로 이어질 수 있는 질문
-- -> 어떤 콘텐츠가 롱런할 가능성이 높은가?
-- -> 초반 순위가 좋은 콘텐츠일수록 롱런할 가능성이 높은가?
-- -> 콘텐츠 유형이 Movie인지 TV Show인지에 따라 롱런 비율이 달라지는가?
-- -> 특정 장르나 계절에 등장한 콘텐츠가 더 오래 Top10에 머무는가?
-- -> 초반 시청 시간이 높은 콘텐츠가 롱런으로 이어지는가?
-- =========================================================
WITH content_summary AS (
    SELECT
        title_clean,
        MIN(show_title) AS show_title,
        type_clean,
        COUNT(DISTINCT week_date) AS weeks_in_top10,
        MIN(weekly_rank_num) AS best_rank,
        MAX(cumulative_weeks_in_top_10_num) AS max_cumulative_weeks,
        -- TODO: 누적 Top10 유지 주가 4주 이상이면 1, 아니면 0으로 만드는 label을 만든다.
        TODO AS long_run_flag
    FROM netflix_content_week_clean
    GROUP BY title_clean, type_clean
)
SELECT
    title_clean,
    show_title,
    type_clean,
    weeks_in_top10,
    best_rank,
    max_cumulative_weeks,
    long_run_flag
FROM content_summary
ORDER BY max_cumulative_weeks DESC, best_rank
LIMIT 30;

-- 이 결과는 모델 input 전체가 아니라, 모델링에서 사용할 label 후보에 가깝다.
-- 장르, 계절, 콘텐츠 유형, 초반 성과 같은 feature를 추가하면
-- "어떤 특성이 롱런 가능성과 관련 있는가?"를 더 구체적으로 볼 수 있다.

-- 완성되면 대략 이런 결과를 기대한다:
-- title_clean     | type_clean | weeks_in_top10 | best_rank | max_cumulative_weeks | long_run_flag
-- stranger things | TV Show    | 12             | 1         | 12                   | 1



-- 정리:
-- 1) Q1~Q2처럼 장르가 분석 단위인 질문은 long format mart가 자연스럽다.
-- 2) 시즌별 급상승 장르는 year + season + genre 집계 뒤 이전 시즌과 비교한다.
-- 3) Q4처럼 콘텐츠 성과 흐름이 분석 단위인 질문은 콘텐츠-주차 intermediate가 자연스럽다.
-- 4) netflix_content_week_clean -> content_summary -> long_run_flag 흐름은
--    이후 모델링에서 target을 만드는 과정으로 볼 수 있다.
