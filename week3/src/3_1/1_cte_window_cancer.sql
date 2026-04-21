-- =========================================================
-- 파일명 예시: warmup_cte_window_cancer.sql
--
-- 목적
-- 이번 워밍업의 목표는 "문법을 외우는 것"이 아니라,
-- 아래 두 가지를 감각적으로 이해하는 것이다.
--
-- 1) CTE (WITH)
--    - 긴 쿼리를 한 번에 쓰지 않고,
--      중간 단계를 나눠서 더 읽기 좋게 만드는 방법
--
-- 2) Window Function
--    - 데이터를 그룹으로 나누거나 정렬하되,
--      각 행을 없애지 않고 순위/평균/비교값을 붙이는 방법
--
-- 사용할 테이블
-- - cancer_data
--
-- 가정 컬럼 예시
-- - diagnosis      : 0/1 (암 여부)
-- - age            : 나이
-- - bmi            : BMI
-- - genetic_risk   : 유전 위험도
--
-- 이 파일의 흐름
-- 1. CTE를 이용해 컬럼을 더 읽기 쉽게 바꾸기
-- 2. Window로 전체 순위 보기
-- 3. Window로 그룹별 순위 보기
-- 4. Window로 그룹 평균과 내 값 비교하기
-- 5. CTE와 Window를 함께 써서 상위 N개만 보기
-- =========================================================



-- =========================================================
-- [예제 1]
-- 무엇을 하려는가?
-- -> diagnosis가 0/1 숫자라 바로 보기 불편하므로,
--    사람이 읽기 쉬운 라벨(Cancer / No Cancer)을 붙인
--    "조금 더 보기 좋은 중간 결과"를 만들고 싶다.
--
-- 왜 이 예제를 먼저 하나?
-- -> CTE를 처음 볼 때는 복잡한 집계보다,
--    "중간 단계에서 컬럼 하나를 더 읽기 좋게 바꿔본다" 정도가 제일 직관적이다.
--
-- 여기서 배우는 핵심
-- -> WITH는 "임시 중간 테이블처럼" 한 단계를 먼저 만들어두고,
--    그 결과를 바깥 SELECT에서 다시 읽어오는 방법이다.
-- =========================================================
WITH diagnosis_labeled AS (
    SELECT
        *,
        CASE
            WHEN diagnosis = 1 THEN 'Cancer'
            ELSE 'No Cancer'
        END AS diagnosis_label
    FROM cancer_data
)
SELECT
    age,
    bmi,
    diagnosis,
    diagnosis_label
FROM diagnosis_labeled
LIMIT 20;



-- =========================================================
-- [예제 2]
-- 무엇을 하려는가?
-- -> 전체 환자 중에서 BMI가 높은 순서대로 순위를 매겨 보고 싶다.
--
-- 왜 이 예제를 하나?
-- -> PARTITION BY까지 바로 들어가면 처음엔 헷갈릴 수 있다.
--    그래서 먼저 "window function은 각 행에 순위를 붙이는 도구"라는 감각을
--    가장 단순한 형태로 먼저 본다.
--
-- 여기서 배우는 핵심
-- -> RANK() OVER (ORDER BY ...) 를 쓰면
--    데이터를 요약하지 않고,
--    각 행에 순위를 추가할 수 있다.
--
-- 주의해서 볼 점
-- -> 행 수는 줄어들지 않는다.
--    즉, GROUP BY처럼 묶어서 줄이는 게 아니라
--    원래 행을 유지한 채 새로운 정보를 덧붙이는 것이다.
-- =========================================================
SELECT
    age,
    bmi,
    diagnosis,
    RANK() OVER (
        ORDER BY bmi DESC
    ) AS bmi_rank_all
FROM cancer_data
ORDER BY bmi_rank_all
LIMIT 20;



-- =========================================================
-- [예제 3]
-- 무엇을 하려는가?
-- -> 방금은 전체 환자를 한 번에 순위 매겼다.
--    이번에는 진단 여부별로 나눠서,
--    각 그룹 안에서 BMI가 높은 사람이 누구인지 보고 싶다.
--
-- 여기서 배우는 핵심
-- -> PARTITION BY를 쓰면
--    전체 순위가 아니라 "그룹별 순위"를 만들 수 있다.
--
-- 추가로 보여주고 싶은 것
-- -> CTE로 diagnosis_label을 먼저 붙이고 나면,
--    바깥 쿼리에서 더 읽기 쉬운 기준으로 분석할 수 있다.
-- =========================================================
WITH diagnosis_labeled AS (
    SELECT
        *,
        CASE
            WHEN diagnosis = 1 THEN 'Cancer'
            ELSE 'No Cancer'
        END AS diagnosis_label
    FROM cancer_data
)
SELECT
    diagnosis_label,
    age,
    bmi,
    RANK() OVER (
        PARTITION BY diagnosis_label
        ORDER BY bmi DESC
    ) AS bmi_rank_in_group
FROM diagnosis_labeled
ORDER BY diagnosis_label, bmi_rank_in_group
LIMIT 30;



-- =========================================================
-- [예제 4]
-- 무엇을 하려는가?
-- -> 각 환자의 BMI가 자기 그룹 평균보다 높은지 낮은지 보고 싶다.
--    즉, 내 BMI만 보는 것이 아니라
--    "내가 속한 집단 평균과 비교했을 때 어느 정도 차이가 나는가"를 보고 싶다.
--
-- 여기서 배우는 핵심
-- -> WINDOW FUNCTION은 평균도 계산할 수 있다.
--    다만 GROUP BY처럼 행을 줄이지 않고,
--    각 행마다 그룹 평균을 붙여줄 수 있다.
--
-- 이 예제를 통해 이해할 것
-- -> GROUP BY는 "요약 결과"를 만드는 도구
-- -> WINDOW는 "원본 행 + 비교 정보"를 함께 보는 도구
-- =========================================================
WITH diagnosis_labeled AS (
    SELECT
        *,
        CASE
            WHEN diagnosis = 1 THEN 'Cancer'
            ELSE 'No Cancer'
        END AS diagnosis_label
    FROM cancer_data
)
SELECT
    diagnosis_label,
    age,
    bmi,
    ROUND(
        AVG(bmi) OVER (PARTITION BY diagnosis_label),
        2
    ) AS group_avg_bmi,
    ROUND(
        bmi - AVG(bmi) OVER (PARTITION BY diagnosis_label),
        2
    ) AS bmi_diff_from_group_avg
FROM diagnosis_labeled
ORDER BY diagnosis_label, bmi DESC
LIMIT 30;



-- =========================================================
-- [예제 5]
-- 무엇을 하려는가?
-- -> 진단 여부별로 BMI가 가장 높은 상위 3명만 보고 싶다.
--
-- 왜 이 예제를 마지막에 하나?
-- -> 지금까지 배운 CTE와 WINDOW FUNCTION을 같이 쓰는 전형적인 패턴이기 때문이다.
--
-- 흐름
-- 1) 먼저 라벨을 붙인다
-- 2) 그다음 그룹별 순위를 계산한다
-- 3) 마지막으로 상위 3명만 남긴다
--
-- 여기서 배우는 핵심
-- -> CTE는 복잡한 로직을 단계별로 쪼개는 데 좋고,
--    WINDOW는 그 안에서 순위 같은 문맥 정보를 만드는 데 좋다.
-- =========================================================
WITH diagnosis_labeled AS (
    SELECT
        *,
        CASE
            WHEN diagnosis = 1 THEN 'Cancer'
            ELSE 'No Cancer'
        END AS diagnosis_label
    FROM cancer_data
),
ranked_patients AS (
    SELECT
        diagnosis_label,
        age,
        bmi,
        genetic_risk,
        RANK() OVER (
            PARTITION BY diagnosis_label
            ORDER BY bmi DESC
        ) AS bmi_rank_in_group
    FROM diagnosis_labeled
)
SELECT
    diagnosis_label,
    age,
    bmi,
    genetic_risk,
    bmi_rank_in_group
FROM ranked_patients
WHERE bmi_rank_in_group <= 3
ORDER BY diagnosis_label, bmi_rank_in_group;



-- =========================================================
-- [정리]
-- 이 파일에서 기억하면 좋은 것
--
-- 1) CTE (WITH)
--    - 긴 쿼리를 한 번에 쓰지 않고,
--      단계별로 나눠서 읽기 좋게 만든다.
--    - 중간 테이블을 만드는 감각과 비슷하다.
--
-- 2) WINDOW FUNCTION
--    - 행을 줄이지 않고,
--      각 행에 순위/평균/비교값을 붙일 수 있다.
--
-- 3) GROUP BY와 WINDOW의 차이
--    - GROUP BY  : 여러 행을 요약해서 결과 행 수가 줄어든다
--    - WINDOW    : 각 행을 유지한 채 추가 정보를 붙인다
--
-- 4) 이 워밍업의 목적
--    - 암 데이터 자체를 깊게 분석하는 것이 아니라
--    - CTE와 WINDOW FUNCTION이 어떤 문제를 푸는 도구인지 감을 잡는 것
-- =========================================================