# 3주차 1회차 세션 문서

- **일시:** 2026.04.23 (목) 16:00
- **진행 방식:** 오프라인(채움 신촌)
- **주제:** SQL 심화 - CTE와 Window Function으로 intermediate / business table 만들기

## 이번 세션 목표

- SQL에서 intermediate table과 business table을 단계적으로 만드는 감각을 익힌다.
- `WITH` 절과 window function이 각각 어떤 문제를 푸는 도구인지 이해한다.
- `GROUP BY`와 `PARTITION BY`의 차이를 구분하고, 각각 언제 더 자연스러운지 감을 잡는다.
- 이후 pandas와 연결할 수 있도록 SQL 결과를 재사용 가능한 테이블로 생각하는 습관을 만든다.

---

## 저번 세션 복습

지난 시간에는 pandas를 사용해 원본 데이터를 바로 쓰지 않고,  
한 번 정리된 **중간 테이블**을 만든 뒤  
그걸 바탕으로 **비즈니스 테이블**까지 가는 흐름을 다뤘습니다.

핵심은 다음과 같았습니다.

- 원본에서 바로 최종 결과를 만들기보다 `원본 -> 중간 -> 비즈니스` 흐름으로 나눈다.
- 중간 단계에서는 품질 정비와 목적에 맞는 변환을 한다.
- 최종 단계에서는 집계, 구조화, 해석 가능한 결과 정리를 한다.

이번 시간에는 같은 흐름을 **pandas가 아니라 SQL 중심으로 다시 구현**해봅니다.

### 지난 세션 핵심 회수 질문

#### Q1.
지난 시간에 만든 `movies_clean`은 왜 원본이 아니라 **중간 테이블**에 가깝다고 볼 수 있을까요?

#### Q2.
비즈니스 테이블은 단순한 집계 결과와 무엇이 다를까요?

#### Q3.
`pivot_table()`과 `melt()`는 각각 어떤 목적에 더 잘 맞았나요?

---

## 이번 세션 핵심 개념

### 1. SQL에서 intermediate / business table을 만든다는 것

이전에는 pandas로 `원본 -> 중간 -> 비즈니스` 흐름을 만들었다면,  
이번에는 SQL에서도 같은 사고를 적용해봅니다.

SQL에서도 보통 다음 같은 흐름을 만듭니다.

- 원본 데이터 확인
- intermediate 성격의 중간 결과 만들기
- 최종 business-ready 결과 만들기

이때 자주 쓰는 SQL 도구는 다음과 같습니다.

- `SELECT / WHERE`: 필요한 행과 컬럼만 고르기
- `JOIN`: 다른 테이블의 정보를 붙여 더 풍부한 결과 만들기
- `GROUP BY / HAVING`: 기준별 요약 결과 만들기
- `ORDER BY`: 보기 좋게 정렬하기
- `WITH (CTE)`: 중간 단계를 나눠서 읽기 쉽게 만들기
- `WINDOW FUNCTION`: 행을 유지한 채 순위, 평균, 비교값 붙이기

즉 이번 시간은  
**SQL 문법 자체보다, SQL로 intermediate와 business table을 어떻게 단계적으로 만들 수 있는지**를 보는 시간입니다.

---

### 2. `WITH` 절은 왜 쓰는가?

`WITH` 절은 긴 쿼리를 한 번에 쓰지 않고,  
중간 단계에 이름을 붙여 나눠 쓰는 방법입니다.

예를 들어 "그룹별 순위를 구하고, 그중 상위 3개만 보기" 같은 흐름을  
한 번에 길게 쓰기보다,

1. 먼저 라벨을 붙이고
2. 그다음 순위를 만들고
3. 마지막에 필요한 행만 고르는 식으로

단계를 나눠 표현할 수 있습니다.

즉 `WITH` 절은  
**SQL 안에서 intermediate 단계를 눈에 보이게 만드는 도구**라고 생각하면 됩니다.

특히 쿼리가 단순할 때보다, **join이 많아지고 intermediate 단계가 늘어날수록** 장점이 더 잘 드러납니다.

- join이 여러 번 들어갈 때
- 중간 집계 후 다시 join할 때
- `정제 -> 조인 -> 집계 -> 최종 필터링`처럼 단계가 많을 때
- window function 결과를 한 번 더 필터링하거나 재사용할 때

이런 경우 서브쿼리만으로도 결과를 만들 수는 있지만,  
쿼리가 안쪽으로 계속 중첩되면서 읽기 어려워지기 쉽습니다.

반면 `WITH` 절은 각 단계에 이름을 붙여서 드러내 주므로,  
**지금 어떤 intermediate를 만들고 있는지** 더 쉽게 설명하고 유지보수할 수 있습니다.

#### `WITH` 절 기본 문법

```sql
WITH cte_name AS (
    SELECT ...
    FROM ...
    WHERE ...
)
SELECT ...
FROM cte_name;
```

#### 간단 예시

아래 예시는 `diagnosis`가 0/1 숫자라 바로 보기 불편하므로,  
읽기 쉬운 라벨을 먼저 붙인 뒤 바깥 쿼리에서 다시 사용하는 경우입니다.

```sql
WITH diagnosis_labeled AS (
    SELECT
        age,
        bmi,
        diagnosis,
        CASE
            WHEN diagnosis = 1 THEN 'Cancer'
            ELSE 'No Cancer'
        END AS diagnosis_label
    FROM cancer_data
)
SELECT
    age,
    bmi,
    diagnosis_label
FROM diagnosis_labeled;
```

이 쿼리는 "라벨 붙이기"를 intermediate 단계로 분리해서  
바깥 쿼리가 더 읽기 쉬워지게 만듭니다.

#### 조금 더 복잡한 예시: join과 집계가 함께 들어가는 경우

예를 들어 부서별 평균 연봉보다 높은 직원만 보고 싶다고 해봅시다.

필요한 흐름은 대략 이렇습니다.

1. 직원과 부서를 join한다.
2. 부서별 평균 연봉을 계산한다.
3. 그 평균을 다시 직원 데이터와 붙인다.
4. 부서 평균보다 높은 직원만 남긴다.

이런 쿼리는 `WITH` 절로 쓰면 단계가 잘 보입니다.

```sql
WITH employee_base AS (
    SELECT
        e.employee_id,
        e.employee_name,
        e.department_id,
        d.department_name,
        e.salary
    FROM employees e
    JOIN departments d
        ON e.department_id = d.department_id
),
department_salary_avg AS (
    SELECT
        department_id,
        AVG(salary) AS avg_salary
    FROM employee_base
    GROUP BY department_id
),
employee_with_avg AS (
    SELECT
        eb.employee_id,
        eb.employee_name,
        eb.department_name,
        eb.salary,
        dsa.avg_salary
    FROM employee_base eb
    JOIN department_salary_avg dsa
        ON eb.department_id = dsa.department_id
)
SELECT
    employee_name,
    department_name,
    salary,
    avg_salary
FROM employee_with_avg
WHERE salary > avg_salary
ORDER BY department_name, salary DESC;
```

이 예시에서 각 CTE는 하나의 논리적 작업만 맡습니다.

- `employee_base`: 기본 join 결과 만들기
- `department_salary_avg`: 부서별 평균 연봉 계산하기
- `employee_with_avg`: 평균 연봉을 다시 붙이기

즉 `WITH` 절은  
`원본 정리 -> 조인 -> 중간 집계 -> 최종 결과` 같은 흐름을  
사람이 읽기 쉬운 단계로 펼쳐놓는 데 강합니다.

같은 로직을 서브쿼리만으로도 만들 수는 있습니다.

```sql
SELECT
    employee_name,
    department_name,
    salary,
    avg_salary
FROM (
    SELECT
        eb.employee_id,
        eb.employee_name,
        eb.department_name,
        eb.salary,
        dsa.avg_salary
    FROM (
        SELECT
            e.employee_id,
            e.employee_name,
            e.department_id,
            d.department_name,
            e.salary
        FROM employees e
        JOIN departments d
            ON e.department_id = d.department_id
    ) eb
    JOIN (
        SELECT
            department_id,
            AVG(salary) AS avg_salary
        FROM (
            SELECT
                e.department_id,
                e.salary
            FROM employees e
            JOIN departments d
                ON e.department_id = d.department_id
        ) base_for_avg
        GROUP BY department_id
    ) dsa
        ON eb.department_id = dsa.department_id
) final_result
WHERE salary > avg_salary
ORDER BY department_name, salary DESC;
```

이 쿼리도 실행은 가능하지만, 읽을 때는 다음 점이 더 불편합니다.

- 어떤 단계가 기본 join인지 바로 눈에 들어오지 않습니다.
- 평균 연봉 계산을 위해 비슷한 join이 다시 등장합니다.
- 안쪽에서 만든 intermediate가 바깥에서 어떤 역할을 하는지 이름만 보고 파악하기 어렵습니다.
- 쿼리가 더 길어지면 괄호와 중첩이 빠르게 복잡해집니다.

즉 복잡한 로직일수록  
서브쿼리는 "안쪽으로 계속 들어가는 구조"가 되고,  
`WITH` 절은 "단계를 옆으로 펼쳐 보여주는 구조"가 됩니다.

---

### 3. 서브쿼리와 `WITH` 절의 차이

둘 다 중간 결과를 만들어 바깥 쿼리에서 쓰는 방식이지만,  
읽히는 방식은 조금 다릅니다.

#### 서브쿼리

- 안쪽에 바로 들어가 있는 쿼리다.
- 짧고 단순할 때는 충분히 괜찮다.
- 단계가 많아질수록 읽기 어려워질 수 있다.

#### `WITH`

- 중간 결과에 이름을 붙여 단계적으로 나눈다.
- intermediate 흐름이 더 잘 드러난다.
- 설명, 디버깅, 재사용이 더 쉽다.

예를 들어 아래 두 쿼리는 모두  
**진단 여부별로 BMI가 높은 상위 3명만 보기**를 위한 쿼리입니다.

#### 서브쿼리 예시

```sql
SELECT *
FROM (
    SELECT
        diagnosis,
        bmi,
        RANK() OVER (
            PARTITION BY diagnosis
            ORDER BY bmi DESC
        ) AS bmi_rank
    FROM cancer_data
) t
WHERE bmi_rank <= 3;
```

#### `WITH` 예시

```sql
WITH ranked_patients AS (
    SELECT
        diagnosis,
        bmi,
        RANK() OVER (
            PARTITION BY diagnosis
            ORDER BY bmi DESC
        ) AS bmi_rank
    FROM cancer_data
)
SELECT *
FROM ranked_patients
WHERE bmi_rank <= 3;
```

두 번째 쿼리는  
`순위를 먼저 만든다 -> 그중 상위 3개만 고른다`는 흐름이 더 잘 드러납니다.

정리하면,

- 작고 단순한 쿼리에서는 서브쿼리로도 충분하고
- join이 많고 단계가 길어질수록 `WITH` 절이 훨씬 유리합니다.

---

### 4. Window Function은 왜 쓰는가?

window function은 데이터를 그룹으로 나누거나 정렬하되,  
각 행을 없애지 않고 순위, 평균, 비교값을 붙이는 함수입니다.

즉,

- `GROUP BY`는 여러 행을 요약해서 줄이는 도구이고
- window function은 원래 행을 유지한 채 문맥 정보를 추가하는 도구입니다.

#### window function 기본 문법

```sql
함수명() OVER (
    PARTITION BY 그룹기준
    ORDER BY 정렬기준
)
```

모든 window function에 `PARTITION BY`와 `ORDER BY`가 항상 둘 다 필요한 것은 아닙니다.

- 전체 기준으로 계산하고 싶으면 `PARTITION BY`를 생략할 수 있습니다.
- 순위처럼 순서가 중요할 때는 `ORDER BY`가 자주 필요합니다.

#### 간단 예시 1: 전체 BMI 순위

```sql
SELECT
    age,
    bmi,
    RANK() OVER (
        ORDER BY bmi DESC
    ) AS bmi_rank_all
FROM cancer_data;
```

이 쿼리는 행 수를 줄이지 않고,  
각 환자 행에 전체 기준 BMI 순위를 붙입니다.

#### 간단 예시 2: 진단 여부별 평균 BMI 비교

```sql
SELECT
    diagnosis,
    age,
    bmi,
    AVG(bmi) OVER (
        PARTITION BY diagnosis
    ) AS group_avg_bmi
FROM cancer_data;
```

이 쿼리는 각 행을 유지한 채,  
내가 속한 `diagnosis` 그룹의 평균 BMI를 같이 보여줍니다.

즉 "그룹 평균 BMI가 얼마냐"만 보고 싶으면 `GROUP BY`가 더 자연스럽고,  
"각 환자의 BMI가 자기 그룹 평균보다 높은가"까지 같이 보고 싶으면 window function이 더 자연스럽습니다.

---

### 5. `GROUP BY`와 `PARTITION BY`는 어떻게 다른가?

둘 다 같은 기준끼리 나누는 느낌이 있지만, 결과는 다릅니다.

#### `GROUP BY`

- 같은 기준끼리 묶는다.
- 여러 행을 하나의 요약 결과로 줄인다.
- 결과 행 수가 줄어든다.

예를 들어 진단 여부별 평균 BMI를 보고 싶다면:

```sql
SELECT
    diagnosis,
    AVG(bmi) AS avg_bmi
FROM cancer_data
GROUP BY diagnosis;
```

결과는 대략 이런 형태입니다.

```text
diagnosis | avg_bmi
0         | 27.10
1         | 29.84
```

#### `PARTITION BY`

- 같은 기준끼리 나누지만 각 행은 유지한다.
- 그 그룹 안에서 순위, 평균, 누적값, 비교값을 붙인다.
- 결과 행 수가 줄어들지 않는다.

예를 들어 진단 여부별 평균 BMI를 각 행에 붙이고 싶다면:

```sql
SELECT
    diagnosis,
    age,
    bmi,
    AVG(bmi) OVER (
        PARTITION BY diagnosis
    ) AS group_avg_bmi
FROM cancer_data;
```

결과는 대략 이런 형태입니다.

```text
diagnosis | age | bmi  | group_avg_bmi
0         | 34  | 24.1 | 27.10
0         | 58  | 29.3 | 27.10
1         | 47  | 31.5 | 29.84
1         | 63  | 28.7 | 29.84
```

즉,

- 요약 결과가 필요하면 `GROUP BY`
- 각 행을 살려둔 채 비교 정보가 필요하면 `PARTITION BY`가 들어간 window function

이라고 보면 됩니다.

---

### 6. 기존 집계 중심 사고에서 window function이 들어오면 무엇이 달라질까?

기존에는 보통 이런 흐름에 익숙합니다.

- 먼저 그룹으로 묶고
- 집계하고
- 정렬하고
- 조건을 걸어서 결과를 줄이는 방식

이건 "그룹별 한 줄 요약표"를 만드는 사고입니다.

그런데 window function이 들어오면 질문 자체가 달라집니다.

이제는 다음 같은 질문을 할 수 있습니다.

- 내 값이 그룹 평균보다 높은가?
- 내가 그룹 안에서 몇 등인가?
- 이전 행과 비교하면 얼마나 달라졌는가?
- 상위 몇 개만 따로 보고 싶은가?

즉 window function이 들어오면  
요약표를 만드는 사고에서  
**원본 행을 유지한 채 문맥 정보를 붙이는 사고**로 확장됩니다.

---

## 질문

가급적 먼저 생각해보고, 필요하면 AI로 보충해봅니다.

### Q1.
`WITH` 절은 왜 굳이 쓸까요?  
서브쿼리로도 비슷한 결과를 만들 수 있는데, intermediate 단계를 나눠 표현하는 데 어떤 장점이 있을까요?

### Q2.
`GROUP BY`와 `PARTITION BY`는 둘 다 비슷하게 보이지만 결과는 다릅니다.  
어떤 상황에서 각각 더 자연스러울까요?

### Q3.
기존에는 `GROUP BY -> HAVING -> ORDER BY` 식의 사고가 익숙했는데,  
window function이 들어오면 어떤 종류의 질문을 더 할 수 있을까요?

### Q4.
"그룹별 평균 BMI"를 보고 싶을 때 왜 어떤 경우에는 `GROUP BY`가 맞고,  
어떤 경우에는 `AVG(...) OVER (...)`가 더 맞을까요?

### Q5.
SQL에서 intermediate table과 business table을 단계적으로 만든 뒤,  
이 결과를 pandas와 연결한다면 어떤 점이 좋아질까요?

---

## 이번 세션 큰 흐름

이번 시간은 크게 두 부분으로 진행됩니다.

### 1. 워밍업: 암 데이터로 CTE / Window Function 감각 잡기

암 데이터는 비교적 작고 단순해서,  
`WITH` 절과 window function의 구조를 빠르게 익히기 좋습니다.

여기서는 주로 다음 흐름을 봅니다.

- `WITH`로 중간 단계 만들기
- 전체 순위 보기
- 그룹별 순위 보기
- 그룹 평균과 내 값 비교하기

핵심은 문법 자체보다,  
이 도구가 어떤 문제를 푸는가를 감각적으로 이해하는 것입니다.

### 2. 확장: 넷플릭스 데이터로 비즈니스 질문 연결하기

그다음에는 넷플릭스 데이터처럼  
실제 intermediate / business table 흐름이 더 잘 보이는 데이터로 확장합니다.

여기서는 다음 흐름을 볼 예정입니다.

- `WITH` 절로 intermediate 단계를 쌓기
- 필요하면 window function으로 순위, 변화량, 비교 정보를 붙이기
- 최종적으로 business-ready 결과 만들기

즉 워밍업은 도구 감각,  
확장은 비즈니스 적용 감각에 더 가깝습니다.

---

## 실습에서 볼 핵심 포인트

이번 실습에서는 아래 질문들을 중심으로 보면 좋습니다.

- 지금 이 쿼리는 중간 단계를 만드는가, 최종 결과를 만드는가?
- `WITH` 절을 쓰면 intermediate 흐름이 더 잘 드러나는가?
- `GROUP BY`로 충분한가, 아니면 window function이 더 자연스러운가?
- 결과를 요약해서 보고 싶은가, 아니면 각 행에 비교 정보를 붙이고 싶은가?
- 나중에 pandas로 가져간다면 어떤 형태의 SQL 결과가 더 활용하기 좋을까?

---

## 회고

### 이번 세션에서 특히 돌아볼 것

- `WITH` 절을 intermediate 단계처럼 이해하는 감각이 생겼는가?
- `GROUP BY`와 `PARTITION BY`의 차이가 조금 더 선명해졌는가?
- 기존 집계 중심 사고에서 window function을 통해 어떤 질문이 추가로 가능해지는지 보였는가?
- SQL만으로도 `정제 -> intermediate -> business-ready` 흐름을 만들 수 있다는 점이 보였는가?
