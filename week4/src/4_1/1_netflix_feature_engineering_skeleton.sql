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
-- - netflix_mart_global       : setup에서 만든 원본 분석용 테이블
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
-- 2. SELECT로 기본 feature 만들어보기
-- 3. WITH로 feature intermediate 분리하기
-- 4. GROUP BY로 장르 business table 만들기
-- 5. LAG()로 이전 주 대비 변화량 feature 만들기
-- 6. 급상승 feature 만들기
-- 7. 롱런 콘텐츠와 단기 인기 콘텐츠 비교하기
-- 8. model input table 후보 만들기
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
    NULLIF(type_clean, 'nan') AS type_clean,
    NULLIF(genre, 'nan') AS genre
FROM netflix_mart_global
WHERE title_clean IS NOT NULL
  AND show_title IS NOT NULL
  AND title_clean NOT LIKE '%�%'
  AND show_title NOT LIKE '%�%'
  AND NULLIF(type_clean, 'nan') IS NOT NULL
  AND NULLIF(genre, 'nan') IS NOT NULL;

-- 확인용: 정제 후 분석 대상 행이 얼마나 남았는지 본다.
SELECT
    COUNT(*) AS clean_rows,
    COUNT(DISTINCT title_clean) AS clean_title_count,
    COUNT(DISTINCT genre) AS clean_genre_count
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
SELECT
    week_date,
    title_clean,
    COUNT(*) AS row_count,
    COUNT(DISTINCT genre) AS genre_count
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
-- -> SELECT에서 바로 기본 feature를 만들어본다.
--
-- 왜 이 예제를 하나?
-- -> WITH로 길게 나누기 전에,
--    CASE WHEN으로 파생 컬럼을 만드는 감각을 먼저 잡기 위함이다.
--
-- 여기서 배우는 핵심
-- -> feature는 거창한 것이 아니라,
--    원본 컬럼을 분석 목적에 맞게 다시 해석한 컬럼이다.
-- =========================================================
SELECT
    week_date,
    show_title,
    weekly_rank_num,
    weekly_hours_viewed_num,
    cumulative_weeks_in_top_10_num,
    -- TODO: weekly_rank_num을 기준으로 순위 구간(rank_bucket)을 만든다.
    TODO AS rank_bucket,
    -- TODO: cumulative_weeks_in_top_10_num을 기준으로 롱런 여부 flag를 만든다.
    TODO AS long_run_flag,
    -- TODO: season을 정렬 가능한 숫자 값으로 바꾼다.
    TODO AS season_order
FROM netflix_mart_clean
ORDER BY week_date DESC, weekly_rank_num
LIMIT 20;

-- 완성되면 대략 이런 결과를 기대한다:
-- week_date  | show_title              | weekly_rank_num | rank_bucket | long_run_flag | season_order
-- 2023-12-17 | The Crown               | 2               | top_3       | 1             | 4



-- =========================================================
-- [예제 3]
-- 무엇을 하려는가?
-- -> 예제 2에서 만든 기본 feature를 WITH로 분리한다.
--
-- 왜 WITH를 쓰는가?
-- -> rank_bucket, long_run_flag, season_order 같은 feature를
--    뒤의 집계나 window 계산에서 다시 쓰기 위함이다.
--
-- 여기서 배우는 핵심
-- -> WITH는 feature intermediate에 이름을 붙여
--    다음 단계에서 읽기 쉽게 재사용하는 방법이다.
-- =========================================================
WITH content_features AS (
    SELECT
        week_date,
        season,
        title_clean,
        show_title,
        weekly_rank_num,
        weekly_hours_viewed_num,
        cumulative_weeks_in_top_10_num,
        type_clean,
        genre,
        -- TODO: 예제 2에서 만든 rank_bucket 로직을 다시 작성한다.
        TODO AS rank_bucket,
        -- TODO: 예제 2에서 만든 long_run_flag 로직을 다시 작성한다.
        TODO AS long_run_flag,
        -- TODO: 예제 2에서 만든 season_order 로직을 다시 작성한다.
        TODO AS season_order
    FROM netflix_mart_clean
)
SELECT
    week_date,
    show_title,
    genre,
    rank_bucket,
    long_run_flag,
    season_order
FROM content_features
ORDER BY week_date DESC, weekly_rank_num
LIMIT 20;

-- 완성되면 대략 이런 결과를 기대한다:
-- week_date  | show_title             | genre     | rank_bucket | long_run_flag | season_order
-- 2023-12-17 | The Crown              | TV Dramas | top_3       | 1             | 4
-- 2023-12-17 | Dr. Seuss' The Grinch  | Comedies  | top_8_to_10 | 1             | 4



-- =========================================================
-- [예제 4]
-- 무엇을 하려는가?
-- -> 글로벌 Top10에 자주 등장하는 장르를 business table로 만든다.
--
-- 왜 이 예제를 하나?
-- -> "어떤 장르가 글로벌에서 잘 먹히는가?"는
--    GROUP BY로 바로 답하기 좋은 설명형 분석 질문이다.
--
-- 여기서 배우는 핵심
-- -> feature table은 행 단위 정보를 보강하는 데 가깝고,
--    business table은 질문에 바로 답하기 좋은 요약 결과에 가깝다.
-- =========================================================
-- 1. 먼저 장르별 등장 횟수와 평균 성과를 요약한다.
SELECT
    genre,
    -- TODO: 장르별 Top10 등장 행 수를 계산한다.
    TODO AS top10_row_count,
    -- TODO: 장르별 고유 콘텐츠 수를 계산한다.
    TODO AS title_count,
    -- TODO: 장르별 평균 순위를 계산한다.
    TODO AS avg_rank,
    -- TODO: 장르별 평균 시청 시간을 계산한다.
    TODO AS avg_hours_viewed
FROM netflix_mart_clean
-- TODO: genre 기준으로 묶는다.
GROUP BY TODO
ORDER BY top10_row_count DESC, avg_rank
LIMIT 20;

-- 완성되면 대략 이런 결과를 기대한다:
-- genre  | top10_row_count | title_count | avg_rank | avg_hours_viewed
-- Drama  | 1200            | 320         | 5.42     | 15000000

-- 2. 장르별 + 계절별로 보면 계절성 질문에 더 가까워진다.
SELECT
    season,
    genre,
    -- TODO: season + genre별 Top10 등장 행 수를 계산한다.
    TODO AS top10_row_count,
    -- TODO: season + genre별 평균 시청 시간을 계산한다.
    TODO AS avg_hours_viewed
FROM netflix_mart_clean
-- TODO: season, genre 기준으로 묶는다.
GROUP BY TODO
ORDER BY season, top10_row_count DESC
LIMIT 40;

-- 완성되면 대략 이런 결과를 기대한다:
-- season | genre                  | top10_row_count | avg_hours_viewed
-- fall   | TV Dramas              | 171             | 38674269
-- winter | International TV Shows | 105             | 21600000



-- =========================================================
-- [예제 5]
-- 무엇을 하려는가?
-- -> 같은 콘텐츠의 이전 주 순위와 시청 시간을 붙여본다.
--
-- 왜 이 예제가 중요한가?
-- -> 급상승, 하락, 신규 진입 같은 feature는
--    현재 행만 봐서는 만들 수 없고 이전 주 정보가 필요하다.
--
-- 여기서 배우는 핵심
-- -> LAG()는 같은 그룹 안에서 이전 행의 값을 가져오는 window function이다.
-- -> 행은 유지하면서 이전 주 정보라는 비교 기준을 붙인다.
-- =========================================================
-- 1. 먼저 콘텐츠별 주차 순서를 확인한다.
SELECT
    title_clean,
    genre,
    week_date,
    weekly_rank_num,
    weekly_hours_viewed_num,
    -- TODO: 콘텐츠 + 장르별 주차 순서를 붙인다.
    TODO AS week_row_num
FROM netflix_mart_clean
ORDER BY title_clean, genre, week_date
LIMIT 40;

-- 완성되면 대략 이런 결과를 기대한다:
-- title_clean | genre | week_date  | weekly_rank_num | weekly_hours_viewed_num | week_row_num
-- example     | Drama | 2023-01-08 | 5               | 8000000                 | 1
-- example     | Drama | 2023-01-15 | 2               | 14000000                | 2

-- 2. LAG()로 이전 주 순위와 이전 주 시청 시간을 붙인다.
WITH weekly_performance AS (
    SELECT
        week_date,
        title_clean,
        show_title,
        genre,
        type_clean,
        weekly_rank_num,
        weekly_hours_viewed_num,
        -- TODO: 같은 콘텐츠 + 장르 기준 이전 주 순위를 가져온다.
        TODO AS prev_week_rank,
        -- TODO: 같은 콘텐츠 + 장르 기준 이전 주 시청 시간을 가져온다.
        TODO AS prev_week_hours_viewed
    FROM netflix_mart_clean
)
SELECT
    week_date,
    show_title,
    genre,
    weekly_rank_num,
    prev_week_rank,
    weekly_hours_viewed_num,
    prev_week_hours_viewed
FROM weekly_performance
ORDER BY title_clean, genre, week_date
LIMIT 40;

-- 완성되면 대략 이런 결과를 기대한다:
-- week_date  | show_title | genre | weekly_rank_num | prev_week_rank | weekly_hours_viewed_num | prev_week_hours_viewed
-- 2023-01-08 | Example    | Drama | 5               |                | 8000000                 |
-- 2023-01-15 | Example    | Drama | 2               | 5              | 14000000                | 8000000



-- =========================================================
-- [예제 6]
-- 무엇을 하려는가?
-- -> 이전 주 대비 변화량과 신규 진입 여부를 feature로 만든다.
--
-- 왜 이 예제를 하나?
-- -> "급상승의 기준은 무엇인가?"라는 질문을
--    SQL feature로 바꾸는 대표 예시이기 때문이다.
--
-- 여기서 배우는 핵심
-- -> WITH로 이전 주 값을 먼저 붙인 뒤,
--    바깥 SELECT에서 변화량과 flag를 계산하면 쿼리가 읽기 쉬워진다.
-- =========================================================
WITH weekly_performance AS (
    SELECT
        week_date,
        season,
        title_clean,
        show_title,
        genre,
        type_clean,
        weekly_rank_num,
        weekly_hours_viewed_num,
        cumulative_weeks_in_top_10_num,
        -- TODO: 같은 콘텐츠 + 장르 기준 이전 주 순위를 가져온다.
        TODO AS prev_week_rank,
        -- TODO: 같은 콘텐츠 + 장르 기준 이전 주 시청 시간을 가져온다.
        TODO AS prev_week_hours_viewed
    FROM netflix_mart_clean
)
SELECT
    week_date,
    show_title,
    genre,
    weekly_rank_num,
    prev_week_rank,
    -- TODO: 이전 순위와 현재 순위의 차이를 계산한다.
    TODO AS rank_change,
    weekly_hours_viewed_num,
    prev_week_hours_viewed,
    -- TODO: 이전 주 대비 시청 시간 변화량을 계산한다.
    TODO AS hours_change,
    -- TODO: 이전 주 대비 시청 시간 증가율을 계산한다.
    TODO AS hours_growth_rate,
    -- TODO: 이전 주 순위가 없으면 신규 진입으로 표시한다.
    TODO AS is_new_entry
FROM weekly_performance
ORDER BY title_clean, genre, week_date
LIMIT 40;

-- 완성되면 대략 이런 결과를 기대한다:
-- week_date  | show_title | genre | weekly_rank_num | prev_week_rank | rank_change | hours_change | is_new_entry
-- 2023-01-08 | Example    | Drama | 5               |                |             |              | 1
-- 2023-01-15 | Example    | Drama | 2               | 5              | 3           | 6000000      | 0

-- 참고:
-- rank_change는 이전 순위 - 현재 순위로 계산했다.
-- 그래서 5위에서 2위가 되면 5 - 2 = 3이고, 양수는 순위 상승을 의미한다.



-- =========================================================
-- [예제 7]
-- 무엇을 하려는가?
-- -> 롱런 콘텐츠와 단기 인기 콘텐츠를 비교할 수 있는 business table을 만든다.
--
-- 왜 이 예제를 하나?
-- -> "Top10에 오래 머무는 콘텐츠와 단기 인기 콘텐츠는 무엇이 다른가?"는
--    먼저 콘텐츠 단위로 요약한 뒤 비교해야 하는 질문이다.
--
-- 여기서 배우는 핵심
-- -> 주차별 행을 콘텐츠 단위로 요약하고,
--    그 결과를 다시 그룹별로 비교할 수 있다.
--
-- 수업 운영
-- -> 1.5시간 수업에서는 이 예제를 전체 실습으로 풀기보다,
--    콘텐츠 단위 요약 흐름을 읽고 일부만 채운다.
-- =========================================================
-- 1. 콘텐츠 + 장르 단위로 먼저 요약한다.
WITH content_summary AS (
    SELECT
        title_clean,
        show_title,
        genre,
        type_clean,
        COUNT(DISTINCT week_date) AS weeks_in_top10,
        MIN(weekly_rank_num) AS best_rank,
        ROUND(AVG(weekly_rank_num), 2) AS avg_rank,
        SUM(weekly_hours_viewed_num) AS total_hours_viewed,
        MAX(cumulative_weeks_in_top_10_num) AS max_cumulative_weeks,
        -- TODO: 최대 누적 유지 주를 기준으로 롱런 여부 flag를 만든다.
        TODO AS long_run_flag
    FROM netflix_mart_clean
    GROUP BY title_clean, show_title, genre, type_clean
)
SELECT
    title_clean,
    show_title,
    genre,
    type_clean,
    weeks_in_top10,
    best_rank,
    avg_rank,
    total_hours_viewed,
    max_cumulative_weeks,
    long_run_flag
FROM content_summary
ORDER BY max_cumulative_weeks DESC, total_hours_viewed DESC
LIMIT 30;

-- 완성되면 대략 이런 결과를 기대한다:
-- title_clean     | genre     | type_clean | weeks_in_top10 | best_rank | total_hours_viewed | long_run_flag
-- stranger things | TV Dramas | TV Show    | 12             | 1         | 1234567890         | 1

-- 2. 롱런 여부별로 장르/유형/성과를 비교한다.
WITH content_summary AS (
    SELECT
        title_clean,
        show_title,
        genre,
        type_clean,
        COUNT(DISTINCT week_date) AS weeks_in_top10,
        MIN(weekly_rank_num) AS best_rank,
        ROUND(AVG(weekly_rank_num), 2) AS avg_rank,
        SUM(weekly_hours_viewed_num) AS total_hours_viewed,
        MAX(cumulative_weeks_in_top_10_num) AS max_cumulative_weeks,
        -- TODO: 최대 누적 유지 주를 기준으로 롱런 여부 flag를 만든다.
        TODO AS long_run_flag
    FROM netflix_mart_clean
    GROUP BY title_clean, show_title, genre, type_clean
)
SELECT
    long_run_flag,
    type_clean,
    genre,
    COUNT(*) AS content_count,
    ROUND(AVG(avg_rank), 2) AS avg_of_avg_rank,
    ROUND(AVG(total_hours_viewed), 0) AS avg_total_hours_viewed
FROM content_summary
GROUP BY long_run_flag, type_clean, genre
ORDER BY long_run_flag DESC, content_count DESC
LIMIT 30;

-- 완성되면 대략 이런 결과를 기대한다:
-- long_run_flag | type_clean | genre     | content_count | avg_of_avg_rank | avg_total_hours_viewed
-- 1             | TV Show    | TV Dramas | 30            | 5.21            | 420000000
-- 0             | Movie      | Comedies  | 45            | 6.10            | 35000000



-- =========================================================
-- [예제 8]
-- 무엇을 하려는가?
-- -> 다음 회차 모델링이나 비교 분석에 넘길 수 있는 model input 후보를 만든다.
--
-- 왜 이 예제를 하나?
-- -> 모델링은 raw 데이터에 바로 들어가는 것이 아니라,
--    행 단위와 feature가 정리된 입력 테이블이 있어야 자연스럽다.
--
-- 여기서 배우는 핵심
-- -> model input table은 보통 "무엇을 한 행으로 볼 것인가"를 먼저 정하고,
--    그 단위에 맞춰 feature를 모은 결과다.
--
-- 수업 운영
-- -> 예제 8은 직접 채우기보다,
--    앞에서 만든 feature들이 최종 입력 테이블로 합쳐지는 모습을 확인한다.
-- =========================================================
WITH weekly_performance AS (
    SELECT
        week_date,
        season,
        title_clean,
        show_title,
        genre,
        type_clean,
        weekly_rank_num,
        weekly_hours_viewed_num,
        cumulative_weeks_in_top_10_num,
        LAG(weekly_rank_num) OVER (
            PARTITION BY title_clean, genre
            ORDER BY week_date
        ) AS prev_week_rank,
        LAG(weekly_hours_viewed_num) OVER (
            PARTITION BY title_clean, genre
            ORDER BY week_date
        ) AS prev_week_hours_viewed
    FROM netflix_mart_clean
),
weekly_features AS (
    SELECT
        week_date,
        season,
        title_clean,
        show_title,
        genre,
        type_clean,
        weekly_rank_num,
        weekly_hours_viewed_num,
        cumulative_weeks_in_top_10_num,
        prev_week_rank,
        prev_week_hours_viewed,
        prev_week_rank - weekly_rank_num AS rank_change,
        weekly_hours_viewed_num - prev_week_hours_viewed AS hours_change,
        CASE
            WHEN prev_week_rank IS NULL THEN 1
            ELSE 0
        END AS is_new_entry,
        CASE
            WHEN cumulative_weeks_in_top_10_num >= 4 THEN 1
            ELSE 0
        END AS long_run_flag,
        CASE
            WHEN weekly_rank_num <= 3 THEN 'top_3'
            WHEN weekly_rank_num <= 7 THEN 'top_4_to_7'
            ELSE 'top_8_to_10'
        END AS rank_bucket,
        CASE season
            WHEN 'spring' THEN 1
            WHEN 'summer' THEN 2
            WHEN 'fall' THEN 3
            WHEN 'winter' THEN 4
        END AS season_order
    FROM weekly_performance
)
SELECT
    week_date,
    title_clean,
    show_title,
    genre,
    type_clean,
    season,
    season_order,
    weekly_rank_num,
    rank_bucket,
    weekly_hours_viewed_num,
    prev_week_rank,
    rank_change,
    prev_week_hours_viewed,
    hours_change,
    is_new_entry,
    long_run_flag
FROM weekly_features
ORDER BY week_date DESC, weekly_rank_num, title_clean, genre
LIMIT 50;

-- 정리:
-- 1) GROUP BY는 질문에 답하는 business table을 만들 때 자연스럽다.
-- 2) LAG(), ROW_NUMBER(), RANK()는 행을 유지한 채 feature를 붙일 때 자연스럽다.
-- 3) WITH는 raw -> intermediate -> business/model input 흐름을 SQL 안에서 보이게 만든다.
