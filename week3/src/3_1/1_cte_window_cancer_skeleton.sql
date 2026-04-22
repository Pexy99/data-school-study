-- =========================================================
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
-- 0. 원본 데이터 확인
-- 1. SELECT로 intermediate 컬럼 추가해보기
-- 2. WITH로 intermediate 결과 재사용하기
-- 3. 정렬 결과와 rank 결과 비교하기
-- 4. Window로 그룹별 순위 보기
-- 5. GROUP BY 평균과 aggregate window 비교하기
-- 6. WITH + Window로 나이대별 BMI 상위 1~3등 보기
-- 7. WITH + Aggregate로 나이대별 암 비율 보기
-- =========================================================



-- =========================================================
-- [예제 0]
-- 무엇을 하려는가?
-- -> 먼저 raw table이 어떻게 생겼는지 본다.
--
-- 여기서 볼 점
-- -> 어떤 컬럼이 있는지
-- -> diagnosis가 0/1 숫자로 들어 있는지
-- -> age, bmi, genetic_risk 같은 분석용 컬럼이 있는지
-- =========================================================
SELECT
    id,
    age,
    gender,
    bmi,
    smoking,
    genetic_risk,
    diagnosis
FROM cancer_data
LIMIT 20;



-- =========================================================
-- [예제 1]
-- 무엇을 하려는가?
-- -> diagnosis가 0/1 숫자라 바로 보기 불편하므로,
--    사람이 읽기 쉬운 라벨(Cancer / No Cancer)을 먼저 붙여본다.
--
-- 왜 이 예제를 먼저 하나?
-- -> WITH를 바로 쓰기 전에,
--    "SELECT 안에서 컬럼을 하나 더 만든다"는 감각을 먼저 잡기 위함이다.
--
-- 여기서 배우는 핵심
-- -> SQL에서도 pandas처럼
--    기존 컬럼을 바탕으로 파생 컬럼을 만들 수 있다.
-- =========================================================
SELECT
    id,
    age,
    bmi,
    diagnosis,
    TODO AS diagnosis_label
FROM cancer_data
LIMIT 20;

-- 완성되면 대략 이런 결과가 나와야 함:
-- id | age | bmi  | diagnosis | diagnosis_label
-- 1  | 34  | 24.1 | 0         | No Cancer
-- 2  | 47  | 31.5 | 1         | Cancer



-- =========================================================
-- [예제 2]
-- 무엇을 하려는가?
-- -> 방금 만든 diagnosis_label을
--    이후 쿼리에서 재사용 가능한 intermediate처럼 다루고 싶다.
--
-- 왜 WITH를 쓰는가?
-- -> 같은 CASE WHEN 로직을 매번 반복해서 쓰는 대신,
--    한 번 이름 붙인 중간 결과를 바깥 SELECT에서 다시 읽기 위해서다.
--
-- 여기서 배우는 핵심
-- -> WITH는 "중간 결과에 이름을 붙이는 방법"이다.
-- -> 단순한 쿼리에서는 서브쿼리로도 충분하지만,
--    단계가 많아질수록 WITH가 훨씬 읽기 쉽다.
-- =========================================================
WITH diagnosis_labeled AS (
    -- 1. diagnosis 숫자를 읽기 쉬운 라벨로 바꾼 intermediate를 만든다.
    SELECT
        id,
        age,
        bmi,
        diagnosis,
        genetic_risk,
        TODO AS diagnosis_label
FROM cancer_data
)
-- 2. intermediate 결과를 다시 읽어온다.
SELECT
    age,
    bmi,
    diagnosis,
    diagnosis_label
FROM diagnosis_labeled
LIMIT 20;

-- 완성되면 대략 이런 결과가 나와야 함:
-- age | bmi  | diagnosis | diagnosis_label
-- 34  | 24.1 | 0         | No Cancer
-- 47  | 31.5 | 1         | Cancer



-- =========================================================
-- [예제 3]
-- 무엇을 하려는가?
-- -> 전체 환자 중에서 BMI가 높은 순서대로 순위를 매겨 보고 싶다.
--
-- 왜 이 예제를 하나?
-- -> PARTITION BY까지 바로 들어가면 처음엔 헷갈릴 수 있다.
--    그래서 먼저 "window function은 각 행에 순위를 붙이는 도구"라는 감각을
--    가장 단순한 형태로 본다.
--
-- 여기서 배우는 핵심
-- -> 단순 정렬과 rank를 붙이는 것은 다르다.
-- -> RANK() OVER (ORDER BY ...) 를 쓰면
--    데이터를 요약하지 않고 각 행에 순위를 추가할 수 있다.
--
-- 주의해서 볼 점
-- -> window function을 썼다고 자동으로 결과가 정렬되는 것은 아니다.
-- -> 보여줄 때는 마지막 SELECT에서 ORDER BY를 명시하는 것이 안전하다.
-- =========================================================
-- 1. 먼저 BMI 기준으로 정렬만 해본다.
SELECT
    age,
    bmi,
    diagnosis
FROM cancer_data
ORDER BY bmi DESC
LIMIT 20;

-- 2. LIMIT / OFFSET으로 일부 구간만 잘라볼 수도 있다.
--    하지만 이건 "몇 번째인지"를 데이터에 남겨주는 것은 아니다.
SELECT
    age,
    bmi,
    diagnosis
FROM cancer_data
ORDER BY bmi DESC
OFFSET 2 LIMIT 7;

-- 3. 이제 각 행에 rank라는 메타데이터를 붙여본다.
SELECT
    age,
    bmi,
    diagnosis,
    TODO AS bmi_rank_all
FROM cancer_data
ORDER BY bmi_rank_all
LIMIT 20;

-- 완성되면 대략 이런 결과가 나와야 함:
-- age | bmi  | diagnosis | bmi_rank_all
-- 52  | 36.4 | 1         | 1
-- 47  | 35.9 | 1         | 2
-- 61  | 35.2 | 0         | 3

-- 4. rank를 붙여두면 "3등부터 10등까지"처럼 중간 구간도 쉽게 자를 수 있다.
--    참고로 "정확히 8행"을 잘라내는 목적이라면 ROW_NUMBER()를 쓸 수도 있다.
--    참고:
--    같은 SELECT에서 만든 bmi_rank_all 별칭을 바로 WHERE에 쓰기는 어렵다.
--    SQL은 보통 FROM -> WHERE -> SELECT -> ORDER BY 순서로 해석되기 때문에,
--    SELECT 단계에서 만든 별칭은 WHERE 시점에는 아직 없다고 보면 된다.
--    그래서 바깥 SELECT나 WITH/서브쿼리로 한 번 감싸서 쓰는 패턴이 자주 나온다.
WITH ranked_all AS (
    SELECT
        age,
        bmi,
        diagnosis,
        TODO AS bmi_rank_all
    FROM cancer_data
)
SELECT
    age,
    bmi,
    diagnosis,
    bmi_rank_all
FROM ranked_all
WHERE TODO
ORDER BY bmi_rank_all;

-- 완성되면 대략 이런 결과가 나와야 함:
-- age | bmi  | diagnosis | bmi_rank_all
-- 61  | 35.2 | 0         | 3
-- 44  | 34.8 | 1         | 4
-- ... | ...  | ...       | ...
-- 39  | 31.0 | 0         | 10



-- =========================================================
-- [예제 4]
-- 무엇을 하려는가?
-- -> 이번에는 전체가 아니라
--    diagnosis 그룹 안에서 BMI가 높은 사람이 누구인지 보고 싶다.
--
-- 여기서 배우는 핵심
-- -> PARTITION BY를 쓰면
--    전체 순위가 아니라 "그룹별 순위"를 만들 수 있다.
--
-- 추가로 볼 점
-- -> PARTITION BY는 diagnosis가 숫자여도 충분히 동작한다.
-- -> 즉, 여기서는 window function 자체가 핵심이지
--    diagnosis_label을 만드는 것이 핵심은 아니다.
-- =========================================================
-- 1. 먼저 diagnosis 숫자 기준으로 그룹별 순위를 바로 계산해본다.
--    그런데 ORDER BY diagnosis, rank 후 LIMIT 20을 하면
--    앞 diagnosis 그룹만 주로 보여서 그룹이 잘 나뉘는지 보기 어렵다.
--    그래서 PARTITION BY를 쓸 때는 각 그룹에서 몇 개씩만 뽑아 보는 패턴도 자주 쓴다.
SELECT
    diagnosis,
    age,
    bmi,
    genetic_risk,
    TODO AS bmi_rank_in_group
FROM cancer_data
ORDER BY diagnosis, bmi_rank_in_group
LIMIT 20;

-- 완성되면 대략 이런 결과가 나와야 함:
-- diagnosis | age | bmi  | genetic_risk | bmi_rank_in_group
-- 0         | 61  | 35.2 | 2            | 1
-- 0         | 58  | 34.1 | 1            | 2
-- 0         | 44  | 33.8 | 3            | 3
-- 1         | 52  | 36.4 | 4            | 1
-- 1         | 47  | 35.9 | 5            | 2
-- 1         | 39  | 34.8 | 3            | 3

-- 2. diagnosis가 0/1이라도 순위 계산은 충분히 가능하다.
--    읽기 편하게 보고 싶다면 마지막 SELECT에서만 라벨을 붙일 수 있다.
WITH ranked_patients AS (
    SELECT
        diagnosis,
        age,
        bmi,
        genetic_risk,
        TODO AS bmi_rank_in_group,
        TODO AS sample_row_num
    FROM cancer_data
)
SELECT
    CASE
        WHEN diagnosis = 1 THEN 'Cancer'
        ELSE 'No Cancer'
    END AS diagnosis_label,
    age,
    bmi,
    genetic_risk,
    bmi_rank_in_group
FROM ranked_patients
WHERE TODO
ORDER BY diagnosis_label, sample_row_num;

-- 완성되면 대략 이런 결과가 나와야 함:
-- diagnosis_label | age | bmi  | genetic_risk | bmi_rank_in_group
-- Cancer          | 52  | 36.4 | 4            | 1
-- Cancer          | 47  | 35.9 | 5            | 2
-- No Cancer       | 61  | 35.2 | 2            | 1



-- =========================================================
-- [예제 5]
-- 무엇을 하려는가?
-- -> 각 환자의 BMI가 자기 그룹 평균보다 높은지 낮은지 보고 싶다.
--
-- 왜 이 예제가 중요한가?
-- -> GROUP BY는 여러 행을 한 줄로 요약한다.
--    반면 window function은 각 행을 유지한 채 비교 정보를 붙인다.
--
-- 여기서 배우는 핵심
-- -> AVG(...) OVER (PARTITION BY ...) 를 쓰면
--    각 행마다 "내가 속한 그룹의 평균"을 함께 볼 수 있다.
-- =========================================================
-- 1. 먼저 GROUP BY로 그룹 평균만 요약해서 본다.
SELECT
    diagnosis,
    ROUND(AVG(bmi), 2) AS avg_bmi
FROM cancer_data
GROUP BY diagnosis
ORDER BY diagnosis;

-- 2. 그런데 이렇게 하면 개별 행은 사라진다.
--    각 행을 유지한 채 그룹 평균을 같이 보고 싶으면 window가 필요하다.
WITH patients_with_avg AS (
    SELECT
        diagnosis,
        age,
        bmi,
        TODO AS group_avg_bmi,
        TODO AS sample_row_num
    FROM cancer_data
)
SELECT
    diagnosis,
    age,
    bmi,
    group_avg_bmi
FROM patients_with_avg
WHERE sample_row_num <=3
ORDER BY diagnosis, sample_row_num;

-- 3. aggregate window는 AVG만 있는 게 아니다.
--    COUNT() OVER (...)를 쓰면 각 행에 "내가 속한 그룹 크기"도 붙일 수 있다.
WITH patients_with_group_stats AS (
    SELECT
        diagnosis,
        age,
        bmi,
        TODO AS group_patient_count,
        TODO AS group_avg_bmi,
        TODO AS sample_row_num
    FROM cancer_data
)
SELECT
    diagnosis,
    age,
    bmi,
    group_patient_count,
    group_avg_bmi
FROM patients_with_group_stats
WHERE TODO
ORDER BY diagnosis, sample_row_num;

-- 4. 여기서도 핵심은 window function이다.
--    diagnosis_label은 읽기 편하게 보여주기 위한 표현일 뿐이다.
WITH patients_with_group_stats AS (
    SELECT
        diagnosis,
        age,
        bmi,
        TODO AS group_avg_bmi,
        TODO AS bmi_diff_from_group_avg,
        TODO AS sample_row_num
    FROM cancer_data
)
SELECT
    CASE
        WHEN diagnosis = 1 THEN 'Cancer'
        ELSE 'No Cancer'
    END AS diagnosis_label,
    age,
    bmi,
    group_avg_bmi,
    bmi_diff_from_group_avg
FROM patients_with_group_stats
WHERE TODO
ORDER BY diagnosis_label, sample_row_num;

-- 완성되면 대략 이런 결과가 나와야 함:
-- diagnosis_label | age | bmi  | group_avg_bmi | bmi_diff_from_group_avg
-- Cancer          | 47  | 31.5 | 29.84         | 1.66
-- No Cancer       | 34  | 24.1 | 27.10         | -3.00



-- =========================================================
-- [예제 6]
-- 무엇을 하려는가?
-- -> 나이대별로 BMI가 높은 상위 10명을 보고 싶다.
--
-- 왜 이 예제를 하나?
-- -> WITH로 intermediate를 만들고,
--    window function으로 각 그룹 top N을 뽑는 흐름을 보기 좋다.
--
-- 흐름
-- 1) 나이대를 만든다
-- 2) 나이대별 BMI 순위를 계산한다
-- 3) 각 나이대 top 10만 남긴다
--
-- 여기서 배우는 핵심
-- -> WITH는 intermediate table을 만들고,
--    window function은 각 그룹 안에서 순위 같은 문맥 정보를 붙이는 데 좋다.
-- =========================================================
-- 1. 먼저 SELECT에서 age_band를 만들어본다.
SELECT
    age,
    bmi,
    diagnosis,
    (age / 10) * 10 AS age_band
FROM cancer_data
LIMIT 20;

-- 2. 이제 이 intermediate를 WITH로 분리한다.
WITH patient_age_band AS (
    SELECT
        id,
        age,
        bmi,
        diagnosis,
        TODO AS age_band
    FROM cancer_data
)
SELECT
    age_band,
    age,
    bmi,
    diagnosis
FROM patient_age_band
LIMIT 20;

-- 3. 그 위에서 나이대별 BMI 순위를 계산한다.
WITH patient_age_band AS (
    SELECT
        id,
        age,
        bmi,
        diagnosis,
        TODO AS age_band
    FROM cancer_data
)
SELECT
    age_band,
    age,
    bmi,
    diagnosis,
    TODO AS bmi_rank_in_age_band
FROM patient_age_band
ORDER BY age_band, bmi_rank_in_age_band
LIMIT 20;

-- 4. 마지막으로 각 나이대 BMI top 10만 남긴다.
WITH patient_age_band AS (
    SELECT
        id,
        age,
        bmi,
        diagnosis,
        TODO AS age_band
    FROM cancer_data
),
ranked_patients AS (
    SELECT
        age_band,
        age,
        bmi,
        diagnosis,
        TODO AS bmi_row_num_in_age_band
    FROM patient_age_band
)
SELECT
    age_band,
    age,
    bmi,
    diagnosis,
    bmi_row_num_in_age_band
FROM ranked_patients
WHERE TODO
ORDER BY age_band, bmi_row_num_in_age_band
LIMIT 20;

-- 완성되면 대략 이런 결과가 나와야 함:
-- age_band | age | bmi  | diagnosis | bmi_row_num_in_age_band
-- 20       | 29  | 33.1 | 0         | 1
-- 20       | 27  | 31.8 | 1         | 2
-- 20       | 24  | 30.9 | 0         | 3



-- =========================================================
-- [예제 7]
-- 무엇을 하려는가?
-- -> 예제 6에서 구한 "나이대별 BMI top 10" 결과를 다시 사용해서
--    그 안에서 나이대별 암 비율을 보고 싶다.
--
-- 왜 이 예제를 하나?
-- -> WITH는 한 번 만든 intermediate를 다른 질문에도 재사용할 수 있음을 보여준다.
-- -> 또 "행 유지"가 필요했던 예제 6 이후에,
--    이번에는 그 결과를 그룹 요약으로 다시 집계하는 흐름을 보여준다.
--
-- 여기서 배우는 핵심
-- -> "각 나이대 top 10"처럼 각 행을 유지하는 질문은 window가 자연스럽다.
-- -> "그 top 10 안에서 나이대별 암 비율"처럼 그룹 요약 질문은 aggregate가 더 자연스럽다.
-- =========================================================
-- 1. 먼저 예제 6의 핵심 결과인 "나이대별 BMI top 10"을 다시 만든다.
WITH ranked_patients AS (
    SELECT
        TODO AS age_band,
        age,
        bmi,
        diagnosis,
        TODO AS bmi_row_num_in_age_band
    FROM cancer_data
)
SELECT
    age_band,
    age,
    bmi,
    diagnosis,
    bmi_row_num_in_age_band
FROM ranked_patients
WHERE TODO
ORDER BY age_band, bmi_row_num_in_age_band
LIMIT 20;

-- 2. WITH로 intermediate를 단계적으로 만든다.
WITH patient_age_band AS (
    SELECT
        id,
        age,
        bmi,
        diagnosis,
        TODO AS age_band
    FROM cancer_data
),
ranked_patients AS (
    SELECT
        age_band,
        age,
        bmi,
        diagnosis,
        TODO AS bmi_row_num_in_age_band
    FROM patient_age_band
)
SELECT
    age_band,
    age,
    bmi,
    diagnosis,
    bmi_row_num_in_age_band
FROM ranked_patients
WHERE TODO
ORDER BY age_band, bmi_row_num_in_age_band
LIMIT 20;

-- 3. 이제 그 결과를 다시 집계해서 나이대별 암 비율을 본다.
--    diagnosis가 0/1이므로 AVG(diagnosis)를 비율처럼 읽을 수 있다.
WITH patient_age_band AS (
    SELECT
        id,
        age,
        bmi,
        diagnosis,
        TODO AS age_band
    FROM cancer_data
),
ranked_patients AS (
    SELECT
        age_band,
        age,
        bmi,
        diagnosis,
        TODO AS bmi_row_num_in_age_band
    FROM patient_age_band
)
SELECT
    age_band,
    TODO AS patient_count,
    TODO AS cancer_patient_count,
    TODO AS cancer_ratio
FROM ranked_patients
WHERE TODO
GROUP BY age_band
ORDER BY age_band;

-- 완성되면 대략 이런 결과가 나와야 함:
-- age_band | patient_count | cancer_patient_count | cancer_ratio
-- 20       | 3             | 1                    | 0.333
-- 30       | 3             | 2                    | 0.667
