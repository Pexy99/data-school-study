# 4주차 1회차 세션 문서

- **일시:** 2026.04.28 (화) 21:30
- **진행 방식:** 온라인
- **주제:** 프로젝트 SQL 실습 - Netflix 데이터로 Feature Engineering 하기

## 이번 세션 목표

이번 회차는 1차 프로젝트 사이클에서 **데이터 확보와 1차 분석용 테이블 구성이 끝난 뒤**,
SQL로 분석과 모델링에 쓸 feature를 만드는 단계입니다.

이번 시간에는 Netflix Top10 데이터를 사용해 다음 흐름을 다룹니다.

- 확보한 raw / 분석용 테이블을 다시 확인한다.
- 비즈니스 질문을 SQL로 풀 수 있는 작업 단위로 바꾼다.
- `WITH`, `JOIN`, `GROUP BY`, window function을 사용해 intermediate / feature table을 만든다.
- 시즌별 장르 변화량과 콘텐츠별 롱런 label을 만든다.

즉 이번 시간의 핵심은
**데이터 확보 이후, SQL로 데이터를 한 번 더 정리하고 feature를 만드는 것**입니다.

---

## 저번 세션 복습

지난 시간에는 `WITH` 절과 window function을 사용해
SQL에서도 intermediate table과 business table을 단계적으로 만들 수 있다는 것을 봤습니다.

핵심은 다음과 같았습니다.

- `WITH`는 긴 쿼리를 단계별 intermediate로 나누는 도구다.
- window function은 행을 유지한 채 순위, 평균, 이전 값 같은 문맥 정보를 붙이는 도구다.
- `GROUP BY`는 여러 행을 요약하고, `PARTITION BY`는 행을 유지한 채 그룹 기준 계산을 한다.

이번 시간에는 이 개념을 연습용 데이터가 아니라
**프로젝트용 Netflix 데이터**에 적용해봅니다.

### 지난 세션 핵심 회수 질문

#### Q1.
intermediate table은 왜 raw table에서 바로 최종 결과로 가지 않고 중간에 만드는 걸까요?

#### Q2.
`GROUP BY`가 더 자연스러운 질문과 window function이 더 자연스러운 질문은 어떻게 구분할 수 있을까요?

#### Q3.
쿼리가 길어질수록 `WITH` 절이 서브쿼리보다 설명하기 쉬워지는 이유는 무엇일까요?

---

## 이번 세션 핵심 개념

### 1. SQL에서 feature engineering을 한다는 것

feature engineering은 원본 컬럼을 그대로 쓰는 것이 아니라,
분석이나 모델링에 더 유용한 형태로 컬럼을 다시 만드는 작업입니다.

이번 Netflix 데이터에서는 예를 들어 다음 같은 질문이 feature로 바뀔 수 있습니다.

- 이전 시즌보다 더 많이 등장한 장르는 무엇인가?
- Top10에 처음 진입한 콘텐츠인가?
- Top10에 오래 머문 롱런 콘텐츠인가?
- 특정 계절에 강하게 나타나는 장르인가?

이런 feature는 보통 SQL에서 다음 문법을 조합해 만듭니다.

- `CASE WHEN`: 조건에 따라 flag나 bucket 만들기
- `JOIN`: 콘텐츠 기본 정보와 주간 Top10 정보 붙이기
- `WITH`: 중간 단계를 이름 붙여 나누기
- `GROUP BY`: 장르, 계절, 유형 기준으로 요약하기
- `LAG()`: 이전 기간 값 가져오기
- `RANK()`: 그룹 안에서 순위 만들기

즉 이번 시간의 SQL은 단순 조회가 아니라
**다음 분석 단계에서 쓸 수 있는 입력 컬럼을 설계하는 작업**에 가깝습니다.

---

### 2. `raw -> intermediate -> business / feature` 흐름

프로젝트 데이터는 보통 raw table을 바로 최종 분석에 쓰지 않습니다.

이번 데이터 기준으로는 다음 흐름으로 생각할 수 있습니다.

- `raw`: 원본에 가까운 수집 데이터
- `intermediate`: 정제, 조인, 날짜/장르/유형 정리, 이전 기간 정보 추가
- `business table`: 질문에 답하기 쉬운 집계 결과
- `feature table`: 이후 분석이나 모델링에서 재사용할 수 있는 행 단위 feature table

이번 세션에서 중요한 것은
**지금 만드는 결과가 어떤 단계의 테이블인지 구분하는 것**입니다.

예를 들어 장르별 평균 시청 시간은 business table에 가깝고,
시즌별 장르 변화량이나 콘텐츠별 `long_run_flag`는 feature table에 더 가깝습니다.

---

### 3. `GROUP BY`, `WITH`, window function의 역할 차이

이번 프로젝트 데이터에서는 세 문법의 역할을 구분하는 것이 중요합니다.

#### `GROUP BY`

여러 행을 묶어서 한 줄 요약을 만들 때 사용합니다.

예시:

- 장르별 Top10 등장 횟수
- 계절별 평균 시청 시간
- 콘텐츠 유형별 롱런 콘텐츠 비율

#### `WITH`

복잡한 쿼리를 단계별 intermediate로 나눌 때 사용합니다.

예시:

- 먼저 주차별 콘텐츠 성과를 정리한다.
- 그다음 이전 시즌 값을 붙인다.
- 마지막에 변화량 feature를 만든다.

#### window function

행을 줄이지 않고, 각 행에 비교 정보나 순위를 붙일 때 사용합니다.

예시:

- 이전 시즌 장르 등장 횟수: `LAG(top10_row_count)`
- 계절 안에서 장르 순위: `RANK()`

정리하면 다음과 같습니다.

- 요약해서 보고 싶다 -> `GROUP BY`
- 중간 단계를 나눠 읽기 쉽게 만들고 싶다 -> `WITH`
- 행은 유지한 채 이전 값, 순위, 변화량을 붙이고 싶다 -> window function

---

### 4. 설명형 SQL 질문과 예측형 모델링 질문의 경계

이번 질문들은 대부분 먼저 SQL로 설명형 분석을 할 수 있습니다.

예를 들어 "롱런 콘텐츠는 어떤 특징이 있는가?"는
SQL로 유형, Top10 유지 주, 최고 순위 등을 비교할 수 있습니다.

하지만 이 질문을 "어떤 콘텐츠가 롱런할지 예측할 수 있는가?"로 바꾸면
그때부터는 모델링 문제에 가까워집니다.

이번 시간에는 모델을 바로 만들기보다,
모델링으로 넘어가기 전에 필요한 feature와 label을 SQL로 준비하는 데 집중합니다.

---

## 데이터 구조와 현재 상태

이번 세션에서는 Netflix 데이터 3개를 기준으로 생각합니다.

### `netflix_titles_raw`

콘텐츠 기본 정보 테이블입니다.

주요 컬럼:

- `show_id`
- `type`
- `title`
- `country`
- `release_year`
- `rating`
- `duration`
- `listed_in`

이 테이블은 콘텐츠의 기본 속성을 확인하거나,
Top10 데이터에 콘텐츠 메타데이터를 붙일 때 기준이 됩니다.

### `all_weeks_global_raw`

글로벌 주간 Top10 원본 데이터입니다.

주요 컬럼:

- `week`
- `category`
- `weekly_rank`
- `show_title`
- `season_title`
- `weekly_hours_viewed`
- `weekly_views`
- `cumulative_weeks_in_top_10`

이 테이블은 주차별 인기 순위와 시청 시간 흐름을 보기 위한 raw 데이터입니다.

### `mart_global_final`

이번 세션에서 주로 사용할 분석용 테이블입니다.

이번 문서에서는 기존 흐름에 맞춰 `raw -> intermediate -> business`라는 말을 계속 사용합니다.
다만 데이터 파일명에 있는 `mart_global_final`의 mart는
"분석에 바로 쓰기 좋게 정리된 테이블" 정도로만 이해하면 됩니다.

raw 데이터에서 제목 정리, 날짜 변환, 월/계절 생성, 타입 정리, 장르 분리, 조인 등을 거쳐 만든 테이블입니다.

주요 컬럼:

- `week_date`: 주차 기준 날짜
- `month_num`: 월
- `season`: 봄/여름/가을/겨울
- `title_clean`: 조인용 표준화 제목
- `show_title`: 원본 제목
- `weekly_rank_num`: 주간 인기 순위
- `weekly_hours_viewed_num`: 주간 시청 시간
- `cumulative_weeks_in_top_10`: Top10 누적 유지 주
- `type_clean`: 콘텐츠 유형
- `genre`: 콘텐츠 장르

현재는 raw 데이터를 조인해 1차 분석용 테이블을 만든 상태입니다.
이번 시간에는 이 테이블 위에서 feature를 다시 설계합니다.

주의할 점은 이 mart가 단순히 장르만 펼친 테이블은 아니라는 것입니다.
일부 TV Show는 같은 주차에 여러 `season_title` 성과 행이 동시에 Top10에 들어올 수 있습니다.
예를 들어 `Stranger Things`가 한 주에 시즌 2, 3, 4까지 같이 순위권이면
성과 행 4개에 장르 3개가 붙어 `week_date + title_clean` 기준으로 12행처럼 보일 수 있습니다.

따라서 `COUNT(*)`는 "Top10 성과 행에 장르가 등장한 횟수"이고,
`COUNT(DISTINCT title_clean)`은 "그 장르에 속한 고유 콘텐츠 수"입니다.
두 지표는 답하는 질문이 다르므로 함께 해석해야 합니다.

---

## 질문 리스트 해석: SQL로 어떻게 구조화할까?

이번 프로젝트 질문은 바로 SQL 쿼리로 바꾸기보다,
먼저 어떤 grain과 feature가 필요한지 나눠 보는 것이 중요합니다.

이번 데이터의 `mart_global_final`은 장르를 행으로 펼친 long format입니다.
그래서 장르 자체가 분석 단위인 Q1~Q2에는 바로 잘 맞지만,
콘텐츠의 롱런 여부를 보려는 Q4에는
`week_date + title_clean` 단위의 콘텐츠-주차 중간 테이블을 새로 만드는 편이 더 안전합니다.

이때 같은 콘텐츠가 같은 주에 여러 성과 행을 가질 수 있으므로,
대표 순위는 가장 좋은 순위, 시청 시간은 중복 제거 후 합계처럼 명시적인 기준으로 접습니다.
이 중간 테이블은 장르 long format mart를 다시 접어서 만들기보다,
`netflix_all_weeks_global`의 주차별 성과와 `netflix_titles`의 메타데이터를 조인해서 새로 만드는 흐름이 실무적으로 더 자연스럽습니다.
이번 실습에서는 시즌별 장르 변화량을 계산하고,
유형 정보까지 붙은 콘텐츠-주차 테이블에서 롱런 여부를 계산합니다.

### Q1. 글로벌 Top10에 자주 등장하는 콘텐츠의 장르는 무엇인가?

이 질문은 **글로벌에서 어떤 장르가 잘 먹히는지**를 보고 싶은 질문입니다.

SQL로는 바로 다룰 수 있습니다.
`genre` 기준으로 묶어서 등장 횟수, 평균 순위, 평균 시청 시간을 보면 됩니다.

필요한 작업:

- `GROUP BY genre`
- `COUNT(*)`로 Top10 등장 횟수 계산
- `AVG(weekly_rank_num)`로 평균 순위 계산
- `AVG(weekly_hours_viewed_num)`로 평균 시청 시간 계산

이 결과는 feature table이라기보다 business table에 가깝습니다.

이 질문은 장르가 분석 단위이므로
`week_date + title_clean + genre`에 가까운 long format mart를 그대로 활용하는 것이 자연스럽습니다.

---

### Q2. 계절별로 선호하는 장르는 무엇인가?

이 질문은 **장르 선호에 계절성이 있는지**를 보고 싶은 질문입니다.

기본적인 계절별 장르 선호는 SQL 집계로 볼 수 있습니다.
`season`, `genre` 기준으로 등장 횟수와 평균 시청 시간을 계산하면 됩니다.

필요한 작업:

- `GROUP BY season, genre`
- 계절별 장르 등장 횟수 계산
- 계절별 평균 시청 시간 계산

이 질문은 장르가 분석 단위이므로 long format mart를 그대로 활용합니다.
급상승처럼 기간 간 변화를 보는 질문은 다음 Q3에서 따로 다룹니다.

---

### Q3. 특정 시즌에 급상승하는 장르는 무엇인가?

이 질문은 모델링 없이 SQL의 기간별 변화량 분석으로 다룰 수 있습니다.

급상승은 SQL에서 이전 시즌 값을 붙여 계산할 수 있습니다.
여기서는 콘텐츠가 아니라 장르의 시즌별 등장 흐름이 핵심입니다.
따라서 `year + season + genre` 단위로 먼저 집계한 뒤,
같은 장르의 이전 시즌 등장 횟수와 비교합니다.

이때 `season`만 쓰면 여러 해가 섞이므로,
`year_num`과 `season_order`를 함께 사용해야 합니다.

필요한 feature:

- `top10_row_count`
- `prev_top10_row_count`
- `count_change`
- `title_count`

여기서는 `LAG()`가 자연스럽습니다.

예를 들어 같은 장르의 이전 시즌 Top10 등장 횟수를 가져온 뒤,
현재 시즌 등장 횟수와 비교하면 급상승 장르를 찾을 수 있습니다.

---

### Q4. Top10에 오래 머무는 롱런 콘텐츠와 단기 인기 콘텐츠는 어떤 차이가 있는가?

이 원본 질문은 롱런 콘텐츠와 단기 인기 콘텐츠를 비교하고,
그 차이에서 **어떤 요인이 콘텐츠를 롱런하게 만드는지**를 보고 싶은 질문으로 해석할 수 있습니다.

다만 SQL만으로 바로 요인을 확정하기보다는,
먼저 롱런 콘텐츠와 비롱런 콘텐츠를 나눌 기준이 필요합니다.
그래서 예제 6에서는 `long_run_flag`를 만들어 롱런 여부를 0/1 label로 정의합니다.

이 질문도 콘텐츠 단위 비교가 먼저입니다.
장르 long format에서 바로 콘텐츠별 합계를 내면 시청 시간이 장르 수만큼 반복 집계될 수 있으므로,
먼저 `netflix_all_weeks_global`에서 만든 콘텐츠-주차 중간 테이블에서 성과를 요약합니다.

이때 콘텐츠-주차 중간 테이블은 이미 장르 중복과 같은 주차 내 여러 성과 행을 접은 상태여야 합니다.

필요한 feature:

- `long_run_flag`
- `max_cumulative_weeks`
- `best_rank`
- `type_clean`

그다음 장르, 계절, 콘텐츠 유형, 초반 순위, 초반 시청 시간 같은 feature를 붙이면
어떤 특성이 롱런 여부와 관련 있는지 비교하거나 모델링할 수 있습니다.

이 결과는 다음 회차에서 예측 문제로 확장할 수도 있습니다.
예를 들어 "어떤 콘텐츠가 롱런할 가능성이 높은가?"로 바꾸면 모델링 문제에 가까워집니다.

예제 6에서 만드는 `long_run_flag`는 이때 요인 분석이나 모델링의 label 후보가 됩니다.
반대로 장르, 계절, 콘텐츠 유형, 초반 순위, 초반 시청 시간은
이 label을 설명하거나 예측하기 위한 feature 후보가 됩니다.

이어질 수 있는 모델링 질문 예시는 다음과 같습니다.

- 어떤 콘텐츠가 롱런할 가능성이 높은가?
- 초반 순위가 좋은 콘텐츠일수록 롱런할 가능성이 높은가?
- 콘텐츠 유형이 Movie인지 TV Show인지에 따라 롱런 비율이 달라지는가?
- 특정 장르나 계절에 등장한 콘텐츠가 더 오래 Top10에 머무는가?
- 초반 시청 시간이 높은 콘텐츠가 롱런으로 이어지는가?

---

## 이번 세션에서 만들 feature 예시

이번 세션의 핵심 산출물은 SQL로 만든 feature입니다.

### 기본 파생 feature

- `prev_top10_row_count`: 같은 장르의 이전 시즌 Top10 등장 횟수
- `count_change`: 현재 시즌 등장 횟수와 이전 시즌 등장 횟수의 차이
- `title_count`: 해당 기간과 장르에 속한 고유 콘텐츠 수

이 feature들은 시즌별로 급상승한 장르를 보기 위해 필요합니다.

이번 세션에서는 이 feature들을 `year + season + genre` grain에서 계산합니다.

### 상태 / 플래그 feature

- `long_run_flag`: Top10에 오래 머문 콘텐츠인지 나타내는 flag

이 feature들은 개별 행을 해석 가능한 상태로 바꿔줍니다.
특히 `long_run_flag`는 다음 단계에서 예측 대상 label로 사용할 수 있습니다.

---

## 이번 시간에 할 일

이번 시간은 모델링 자체보다 SQL 데이터 준비 단계에 집중합니다.

1. `mart_global_final` 구조를 확인한다.
2. 질문별로 필요한 grain을 정한다.
3. Q1~Q2는 long format mart로 장르 business table을 만든다.
4. Q3은 시즌별 급상승 장르를 계산한다.
5. Q4는 raw 성과 테이블에서 콘텐츠-주차 intermediate를 새로 만든 뒤 롱런 label을 만든다.

여기서 grain은 "한 행이 무엇을 의미하는가"입니다.

예를 들어 장르별 성과를 보려면
한 행은 `week_date + title_clean + genre` 단위가 될 수 있습니다.

반대로 콘텐츠의 롱런 여부를 보려면
한 행은 `week_date + title_clean` 단위가 더 적절합니다.

장르별 요약 결과를 만들 때는
한 행은 `genre` 또는 `season + genre` 단위가 됩니다.

---

## 이번 세션에서 특히 볼 포인트

- 지금 만드는 결과가 단순 집계인지, intermediate feature인지 구분할 수 있는가
- `GROUP BY`와 `LAG()` 중 어느 쪽이 더 자연스러운 문제인지 판단할 수 있는가
- 같은 질문을 설명형 분석과 예측형 문제로 나눠 볼 수 있는가
- SQL 결과를 이후 분석이나 모델링에 쓸 feature 형태로 생각할 수 있는가

이번 세션의 목표는 모든 질문에 최종 답을 내는 것이 아닙니다.
질문을 SQL 작업으로 나누고, 다음 단계에 넘길 수 있는 feature를 만드는 것입니다.

---

## 다음 세션 예고

다음 시간에는 이번 시간에 만든 intermediate / feature table을 바탕으로
간단한 모델링 또는 비교 분석으로 넘어갈 수 있습니다.

예를 들어 다음 같은 방향으로 확장할 수 있습니다.

- 롱런 콘텐츠 여부를 예측하는 간단한 분류 문제
- 급상승 콘텐츠와 일반 콘텐츠의 feature 비교
- 장르, 계절, 유형별 성과 차이 시각화
- 모델 평가 지표 확인

---

## 참고 링크

- [PostgreSQL: WITH Queries (CTE)](https://www.postgresql.org/docs/current/queries-with.html)
- [PostgreSQL: Window Functions Tutorial](https://www.postgresql.org/docs/current/tutorial-window.html)
- [PostgreSQL: Window Functions Reference](https://www.postgresql.org/docs/current/functions-window.html)
