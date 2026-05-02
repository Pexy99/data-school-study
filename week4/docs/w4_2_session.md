# 4주차 2회차 세션 문서

- **일시:** 2026.05.03 (일) 13:00
- **진행 방식:** 온라인
- **주제:** Netflix 롱런 예측 데모 - Feature Table 기반 롱런 예측 실험

## 이번 세션 목표

이번 회차는 4주차 1회차에서 만든 SQL feature와 label을 바탕으로, 전통 ML 모델링 흐름을 Netflix 데이터에 적용해 해석하는 시간입니다.
전통 ML 개념 자체는 이미 기준 강의와 Azure ML 실습에서 다뤘으므로, 이번 시간은 새 알고리즘을 배우기보다 프로젝트 데이터에 적용된 실험 결과를 읽는 데 집중합니다.

이번 시간의 핵심은 모델 코드를 직접 작성하는 것이 아니라, 준비된 Python 데모를 보면서 **ML 실험의 전체 흐름과 결과 해석 방식**을 이해하는 것입니다.

중요하게 볼 포인트는 세 가지입니다.

- SQL로 만든 feature/label이 Python 모델링 입력으로 이어지는 흐름을 이해한다.
- leakage, 예측 시점, train/test split처럼 ML 실험에서 주의해야 할 지점을 확인한다.
- 모델 성능을 지표와 threshold로 해석하고, 요약형 대시보드나 운영 의사결정으로 확장해 본다.

이번 노트북의 흐름은 다음과 같이 봅니다.

```text
EDA / 관계 확인
  ↓
데이터 스플릿
  ↓
Baseline 모델
  ↓
모델 교체
  ↓
파라미터 튜닝
  ↓
결과 해석
  ↓
비즈니스 확장 / 대시보드
```

즉 이번 시간의 핵심은 **모델을 많이 돌리는 것보다, ML 실험을 어떤 순서로 구성하고 어떤 기준으로 해석할지 보는 것**입니다.

---

## 저번 세션 복습

지난 시간에는 Netflix Top10 데이터를 사용해 SQL 기반 feature engineering을 다뤘습니다.

핵심은 다음과 같았습니다.

- `mart_global_final` 구조 확인
- 질문별 필요한 grain 구분
- `GROUP BY`로 장르/계절별 business table 생성
- `LAG()`로 시즌별 장르 변화량 계산
- 콘텐츠 단위 롱런 여부를 나타내는 `long_run_flag` 생성
- SQL 결과를 다음 단계의 분석/모델링 입력으로 생각하기

지난 시간의 흐름은 다음과 같았습니다.

```text
raw data
  ↓
intermediate table
  ↓
feature table / business table
  ↓
modeling or visualization
```

이번 시간에는 이 중 `feature table -> model input table -> modeling -> evaluation -> dashboard` 흐름을 봅니다.

현재 2회차 노트북 흐름은 다음처럼 확장되어 있습니다.

```text
model input table
  ↓
EDA / 관계 확인
  ↓
leakage 확인
  ↓
train/test split
  ↓
baseline 모델
  ↓
모델 교체
  ↓
파라미터 튜닝
  ↓
결과 해석 / threshold
  ↓
HTML 요약 대시보드
```


### 지난 세션 핵심 회수 질문

#### Q1.

지난 시간에 `long_run_flag`는 어떤 기준으로 만들었나요?

#### Q2.

롱런 여부를 보려면 왜 장르 long format mart를 그대로 쓰지 않고 콘텐츠-주차 테이블을 따로 만들었나요?

#### Q3.

`weeks_in_top10`이나 `max_cumulative_weeks`는 `long_run_flag`와 어떤 관계가 있나요?
이 컬럼들을 모델 feature로 넣으면 왜 위험할 수 있을까요?

---

## 이번 세션 핵심 개념

### 1. 모델링 문제 정의

이번 세션에서 다룰 문제는 다음과 같습니다.

> Netflix Top10에 진입한 콘텐츠가 롱런할 가능성이 있는가?

예측 시점은 다음처럼 고정합니다.

> Top10 첫 진입 주차에 알 수 있는 정보만 보고, 이후 롱런 여부를 예측한다.

이를 ML 문제로 바꾸면 다음과 같습니다.

| 항목 | 정의 |
| --- | --- |
| 문제 유형 | 분류 classification |
| target | `long_run_flag` |
| positive class | 롱런 콘텐츠 |
| input feature | 콘텐츠 유형, 장르, 첫 진입 시점의 순위/시청시간, 계절, 월 등 |

왜 회귀가 아니라 분류일까요?

이번 target은 “Top10에 몇 주 머무를지”라는 연속적인 값을 직접 맞히는 것이 아닙니다.
`max_cumulative_weeks >= 4`라는 기준으로 `long_run_flag`를 만들고, 이 값이 1인지 0인지 맞히는 문제입니다.
따라서 이번 문제는 유지 주 수를 예측하는 회귀 문제가 아니라, 롱런/비롱런을 구분하는 분류 문제로 봅니다.

예시 target:

```text
long_run_flag = 1  if max_cumulative_weeks >= 4
long_run_flag = 0  otherwise
```

여기서 중요한 것은 모델이 “전체 Netflix 콘텐츠 성공 여부”를 예측하는 것이 아니라는 점입니다.

이 모델은 더 정확히 말하면 **Top10에 이미 진입한 콘텐츠 중, 롱런할 가능성을 예측하는 모델**입니다.

---

### 2. Feature Table과 Target

모델링에 사용할 데이터는 보통 다음처럼 나눕니다.

```text
X = feature columns
y = target column
```

예시 model input table:

| title_clean | type_clean | primary_genre | first_season | first_month_num | first_week_rank | first_week_hours_viewed | long_run_flag |
| --- | --- | --- | --- | --- | --- | --- | --- |

여기서 `long_run_flag`는 맞혀야 할 정답이고, 나머지 컬럼들은 예측에 사용할 입력입니다.

중요한 것은 예측 시점에 알 수 있는 정보만 feature로 사용해야 한다는 점입니다.

1회차에서 만든 것은 콘텐츠-주차 intermediate와 `long_run_flag`의 기준입니다.
이번 2회차에서는 이를 바탕으로 미리 준비한 데모용 model input table을 사용합니다.

이번 스터디에서는 DB에 준비된 `netflix_model_input` 테이블을 Python에서 `read_sql`로 가져오는 흐름을 기본으로 봅니다.
실무 흐름은 SQL table -> Python model input에 가깝기 때문입니다.
다만 DB 연결이 어려운 환경을 대비해 같은 schema의 CSV도 백업 자료로 둘 수 있습니다.

---

### 3. EDA와 상관관계: 모델 전에 먼저 볼 것

모델을 바로 돌리기 전에, safe feature와 `long_run_flag`가 어떤 관계를 보이는지 먼저 확인합니다.

이번 노트북에서는 다음을 봅니다.

- 숫자형 feature와 `long_run_flag`의 상관계수
- 콘텐츠 유형별 롱런 비율
- 대표 장르별 롱런 비율
- 첫 진입 순위와 롱런 여부 차이
- 첫 주 시청시간 bucket별 롱런 비율

숫자형 feature는 `corr()`로 상관계수를 볼 수 있습니다.
예를 들어 `first_week_rank`는 숫자가 작을수록 좋은 순위이므로, `long_run_flag`와 음의 상관관계가 나오면 첫 진입 순위가 좋을수록 롱런과 관련이 있다고 해석할 수 있습니다.

반면 `type_clean`, `primary_genre`, `first_season` 같은 범주형 feature는 일반적인 Pearson 상관계수보다 그룹별 롱런 비율로 보는 편이 더 직관적입니다.

중요한 점은 다음입니다.

> 상관관계나 그룹별 차이는 "관련이 있다"는 힌트이지, "원인이다"라는 결론은 아니다.

따라서 이번 세션에서는 “무엇이 롱런을 만들었다”보다 “롱런 콘텐츠와 비롱런 콘텐츠는 어떤 feature 차이를 보였는가”, “모델은 어떤 feature를 중요하게 사용했는가”로 표현합니다.

---

### 4. Leakage: 성능이 좋아 보이지만 실제론 틀린 실험

Leakage는 예측 시점에 알 수 없어야 하는 정보가 학습이나 평가에 섞여 들어가서, 모델 성능이 실제보다 좋아 보이는 문제입니다.
scikit-learn도 leakage를 피하려면 train/test split을 먼저 하고, test data를 fit이나 fit_transform에 포함하지 말아야 한다고 설명합니다.

스터디에서는 이렇게 이해하면 됩니다.

```text
leakage = 시험 전에 답안지를 본 상태
```

Netflix 데이터에서 leakage가 생길 수 있는 예시는 다음과 같습니다.

#### 예시 1. 정답과 거의 같은 컬럼을 feature로 넣는 경우

예를 들어 `long_run_flag`를 이렇게 만들었다고 합시다.

```text
long_run_flag = 1 if max_cumulative_weeks >= 4
```

그런데 feature에 아래 컬럼을 넣으면 문제가 됩니다.

```text
max_cumulative_weeks
weeks_in_top10
```

이 컬럼들은 target을 만드는 데 직접 연결된 값입니다.
즉 모델이 진짜 예측한 것이 아니라, 정답에 가까운 정보를 미리 본 셈입니다.

#### 예시 2. 미래 정보를 feature로 넣는 경우

문제가 다음과 같다고 합시다.

> 첫 진입 주차 정보만 보고 이 콘텐츠가 롱런할지 예측한다.

그런데 feature에 아래 컬럼을 넣으면 leakage가 될 수 있습니다.

```text
avg_weekly_hours_viewed
max_weekly_hours_viewed
best_rank
weeks_in_top10
```

이 값들은 전체 Top10 기간을 다 본 뒤에야 알 수 있는 값일 수 있습니다.
첫 진입 시점에는 아직 알 수 없으므로, “예측” 문제에는 부적절할 수 있습니다.

#### 예시 3. train/test split 전에 전체 데이터로 전처리하는 경우

예를 들어 전체 데이터에 대해 먼저 scaling이나 encoding을 fit한 뒤 train/test를 나누면 test 데이터의 정보가 전처리 과정에 섞일 수 있습니다.

그래서 실무에서는 보통 다음 흐름을 지킵니다.

- 먼저 train/test split
- train data에만 전처리 fit
- test data에는 transform만 적용

scikit-learn도 이런 실수를 줄이기 위해 Pipeline 사용을 권장합니다.

---

## 이번 세션에서 사용할 데이터 버전

이번 데모에서는 두 가지 model input 버전을 비교할 수 있습니다.

### 1. Leakage 포함 버전

예시:

```text
title_clean
type_clean
weeks_in_top10
best_rank
max_cumulative_weeks
long_run_flag
```

이 버전은 성능이 매우 좋아 보일 수 있습니다.
하지만 `long_run_flag`와 직접 연결된 정보가 feature에 포함되어 있으므로 예측 실험으로는 부적절합니다.

이 버전의 목적은 **leakage가 있으면 성능이 얼마나 쉽게 부풀려질 수 있는지 보여주는 것**입니다.

### 2. 예측용 Safe Feature 버전

예시:

```text
title_clean
type_clean
primary_genre
first_season
first_month_num
first_week_rank
first_week_hours_viewed
initial_rank_bucket
initial_hours_bucket
long_run_flag
```

이 버전은 첫 진입 시점에 알 수 있는 정보만 사용합니다.

이 버전의 목적은 **실제로 예측 시점에 사용할 수 있는 정보만으로 롱런 여부를 예측해보는 것**입니다.

두 버전 모두 스터디 전에 데모용 테이블로 준비해 둡니다.
Python에서는 SQL 테이블을 우선 사용하고, 같은 내용을 담은 CSV는 재현이나 백업용으로만 사용합니다.

---

## 모델링 흐름

이번 시간에는 모델을 하나만 돌리고 끝내지 않습니다.
다만 모델 코드를 새로 작성하는 것이 아니라, 준비된 코드의 결과를 보며 전통 ML 실험 흐름을 해석합니다.

노트북의 실제 흐름은 다음과 같습니다.

```text
model input table
  ↓
EDA / 관계 확인
  ↓
leakage 확인
  ↓
train/test split
  ↓
baseline 모델
  ↓
모델 교체
  ↓
파라미터 튜닝
  ↓
결과 해석 / threshold
  ↓
HTML 요약 대시보드
```

### 1. EDA / 관계 확인

모델을 만들기 전에 feature와 `long_run_flag`의 관계를 먼저 봅니다.

- 숫자형 feature는 `corr()`로 `long_run_flag`와의 상관계수를 확인합니다.
- 범주형 feature는 콘텐츠 유형별, 장르별, 시청시간 bucket별 롱런 비율을 봅니다.
- 이 단계의 결론은 “관련이 있어 보인다” 정도로 제한합니다.

### 2. Leakage 확인

safe feature만 쓴 모델과 leakage feature가 포함된 모델을 비교합니다.

leakage 모델의 성능이 훨씬 좋아 보일 수 있지만, 이것은 예측을 잘한 것이 아니라 정답에 가까운 정보를 미리 본 결과일 수 있습니다.
그래서 이 단계의 목적은 좋은 모델을 고르는 것이 아니라, **성능이 너무 좋아 보일 때 무엇을 의심해야 하는지** 확인하는 것입니다.

### 3. Train/test split으로 기본 검증 구조 만들기

모델을 학습하기 전에 데이터를 train/test로 나눕니다.

```text
전체 데이터
  -> train data: 모델 학습용
  -> test data : 마지막 성능 확인용
```

`stratify=y`를 사용해 train/test 양쪽에 롱런/비롱런 비율이 비슷하게 유지되도록 합니다.
이 test data는 모델을 고르는 데 쓰지 않고, 마지막 성능 확인용으로 남겨둡니다.

### 4. Baseline 모델 만들기

처음부터 복잡한 모델로 가지 않고, 단순한 모델로 기준점을 만듭니다.

예시:

- `LogisticRegression`

이름에 Regression이 들어가지만, scikit-learn의 `LogisticRegression`은 분류 모델로 사용합니다.
이번 문제에서 이 모델은 “몇 주 유지될지”를 예측하는 것이 아니라, 롱런 class label 또는 롱런 확률을 예측합니다.

Baseline의 목적은 다음과 같습니다.

- 최소 기준 성능 확인
- 복잡한 모델이 정말 더 나은지 비교할 기준 만들기
- 문제 자체가 예측 가능한 문제인지 확인
- 빠르고 단순한 모델로 먼저 출발해 이후 모델 교체의 기준점 만들기

### 5. 모델 교체

다음으로 더 강한 모델을 비교합니다.

예시:

- `RandomForestClassifier`

트리 기반 모델은 표형 데이터에서 강한 경우가 많습니다.
표 형태 데이터는 숫자형 feature와 범주형 feature가 섞여 있고, feature 간 관계가 선형적이지 않을 수 있습니다.
예를 들어 `first_week_rank <= 특정 값`, `type_clean = TV Show` 같은 조건 분기가 성과 차이를 만들 수 있습니다.

결정트리 계열 모델은 이런 threshold 기반 분기를 자연스럽게 학습할 수 있습니다.
`RandomForestClassifier`는 여러 결정트리를 묶어 평균/투표로 예측하므로, 단일 결정트리보다 더 안정적인 결과를 기대할 수 있습니다.

여기서는 `LogisticRegression` baseline과 `RandomForestClassifier` 결과를 비교합니다.
또한 RandomForest의 feature importance를 확인합니다.
다만 feature importance는 모델이 예측에 많이 사용한 feature를 뜻할 뿐, 롱런의 원인을 뜻하지는 않습니다.

### 6. 파라미터 튜닝

`RandomizedSearchCV`는 여러 하이퍼파라미터 조합 중 일부를 랜덤하게 뽑아 시도하고, 교차검증 점수가 좋은 조합을 찾는 scikit-learn 도구입니다.

이번 노트북에서는 RandomForest의 다음 설정 후보를 탐색합니다.

- `n_estimators`
- `max_depth`
- `min_samples_leaf`
- `max_features`

`cv=3`은 train data를 3개 fold로 나눠 검증한다는 뜻입니다.

```text
train data
  -> 3-fold cross validation으로 여러 파라미터 조합 비교
  -> 가장 나은 조합 선택
  -> 선택된 모델을 test data에서 최종 평가
```

중요한 점은 `cv=3`이 test data를 쓰는 것이 아니라, train data 내부를 3개 fold로 나눠 튜닝 조합을 비교하는 장치라는 점입니다.

`RandomizedSearchCV`의 장점은 다음과 같습니다.

- 시간 예산을 `n_iter`로 조절할 수 있습니다.
- 탐색 후보가 많을 때 모든 조합을 다 보지 않아도 됩니다.
- baseline과 기본 RandomForest를 넘어, 설정을 바꿨을 때 결과가 얼마나 달라지는지 볼 수 있습니다.

단점도 있습니다.

- 모든 조합을 확인하지는 않습니다.
- `cv` 성능이 좋아도 test data 성능이 항상 좋아지는 것은 아닙니다.
- 튜닝보다 leakage 방지와 예측 시점 정의가 더 중요할 수 있습니다.

### 7. 결과 해석 / Threshold

모델은 보통 0/1 label만 내는 것이 아니라, `long_run_probability` 같은 확률 점수를 만듭니다.
이 확률을 어떤 기준으로 1로 바꿀지 정하는 값이 threshold입니다.

- threshold를 낮추면 더 많은 콘텐츠를 롱런 후보로 잡습니다.
- threshold를 높이면 더 확실한 콘텐츠만 롱런 후보로 잡습니다.
- threshold 선택은 Precision / Recall tradeoff와 직접 연결됩니다.

### 8. HTML 요약 대시보드 확인

마지막으로 모델 결과를 HTML 요약 대시보드로 확인합니다.
대시보드는 `RandomForest_randomized_search` 모델의 예측 확률을 사용합니다.

대시보드의 목적은 콘텐츠 검색이 아니라, 다음 정보를 한눈에 보는 것입니다.

- 예측 롱런 후보 수
- Precision / Recall
- Threshold별 tradeoff
- 콘텐츠 유형별 평균 롱런 확률
- 대표 장르별 평균 롱런 확률
- False Positive / False Negative 요약
- 상위 롱런 후보

---

## 모델 비교에서 볼 메시지

노트북에서는 다음 세 모델을 비교합니다.

| 모델 | 역할 | 해석 포인트 |
| --- | --- | --- |
| `LogisticRegression_safe` | baseline | 단순한 기준 모델, 롱런 후보를 비교적 넓게 잡는지 확인 |
| `RandomForest_safe` | 모델 교체 | 표형 데이터의 조건 분기를 학습하지만, 더 보수적으로 예측할 수 있음 |
| `RandomForest_randomized_search` | 튜닝 모델 | train data 내부 3-fold CV로 선택된 RandomForest |

모델 비교에서 중요한 것은 “튜닝 모델이 무조건 최고”가 아닙니다.
목적에 따라 어떤 지표를 볼지 정해야 합니다.

- 롱런 후보를 놓치지 않는 것이 중요하면 Recall을 본다.
- 후보를 적게 잡더라도 정확한 것이 중요하면 Precision을 본다.
- 확률 순위화 능력을 보고 싶으면 ROC-AUC를 본다.
- 운영에서 사용할 최종 판정은 threshold와 함께 본다.

---

## 평가 지표

이번 세션에서는 단순 accuracy만 보지 않고 여러 지표를 함께 봅니다.
scikit-learn은 confusion matrix, precision, recall, F-measure, ROC-AUC 등 다양한 분류 평가 지표를 제공합니다.

### Accuracy

전체 중 맞힌 비율입니다.

> 전체적으로 얼마나 맞췄는가?

단, 클래스 불균형이 있으면 착시가 생길 수 있습니다.

### Precision

롱런이라고 예측한 것 중 실제 롱런인 비율입니다.

> 우리가 “롱런할 것”이라고 찍은 콘텐츠가 얼마나 믿을 만한가?

비즈니스 관점:

- 마케팅 예산을 낭비하면 안 될 때 중요합니다.
- False Positive, 즉 롱런할 것이라고 봤지만 실제로는 금방 사라지는 콘텐츠의 비용이 클 때 중요합니다.

### Recall

실제 롱런 콘텐츠 중 모델이 잡아낸 비율입니다.

> 진짜 롱런 콘텐츠를 얼마나 놓치지 않았는가?

비즈니스 관점:

- 좋은 콘텐츠를 놓치면 안 될 때 중요합니다.
- False Negative, 즉 실제로 롱런할 콘텐츠를 놓치는 비용이 클 때 중요합니다.

### F1-score

Precision과 Recall의 균형 점수입니다.
scikit-learn은 F1을 precision과 recall의 조화평균으로 설명합니다.

> 헛다리도 줄이고, 놓치는 것도 줄이고 싶을 때 보는 균형 점수

### ROC-AUC

예측 확률이 양성과 음성을 얼마나 잘 구분하는지 보는 지표입니다.

> 임계값을 바꿔도 모델이 두 클래스를 잘 구분하는가?

### Confusion Matrix

실제 값과 예측 값의 조합을 표로 보여줍니다.

예를 들어:

| | 예측 비롱런 | 예측 롱런 |
| --- | --- | --- |
| 실제 비롱런 | TN | FP |
| 실제 롱런 | FN | TP |

이 표를 보면 모델이 어떤 방식으로 틀리는지 확인할 수 있습니다.

정리하면, 운영 비용이 어디에서 더 크게 발생하는지에 따라 중요 지표가 달라집니다.
마케팅 예산 낭비를 줄이는 것이 중요하면 Precision을 더 볼 수 있고, 롱런 가능성이 있는 콘텐츠를 놓치지 않는 것이 중요하면 Recall을 더 볼 수 있습니다.

---

## HTML 요약 대시보드 데모

이번 세션에서는 노트북 결과를 정적 HTML 대시보드로도 확인합니다.
대시보드는 `RandomForest_randomized_search` 모델의 예측 결과를 사용합니다.
즉 baseline이 아니라, `RandomizedSearchCV(cv=3)`로 선택한 RandomForest 모델의 `long_run_probability`를 보여줍니다.

threshold 기본값은 `0.50`입니다.
0.50 이상이면 롱런 후보로 표시합니다.
하지만 실제 운영에서는 FP/FN 비용에 따라 threshold를 더 높이거나 낮출 수 있습니다.

대시보드는 검색/필터 중심이 아니라, 한눈에 들어오는 요약 화면으로 구성합니다.

- 예측 롱런 후보 수
- Precision / Recall
- Threshold별 tradeoff
- 콘텐츠 유형별 평균 롱런 확률
- 대표 장르별 평균 롱런 확률
- False Positive / False Negative 요약
- 상위 롱런 후보 12개

핵심 메시지는 다음과 같습니다.

> 모델 결과는 노트북 안에서 끝나는 것이 아니라, 운영자가 바로 판단할 수 있는 요약형 decision support dashboard로 이어질 수 있다.

---

## 실무 확장: 롱런 예측은 어디에 쓸 수 있을까?

이번 실습의 모델은 단순히 `long_run_flag`를 맞히는 것이 목적이 아닙니다.

비즈니스 관점에서는 다음 질문으로 해석할 수 있습니다.

> 이번 주 성과가 좋은 콘텐츠가 앞으로도 지속될 가능성이 있는가?

이 예측은 다음과 같은 의사결정으로 확장될 수 있습니다.

### 1. 콘텐츠 운영

롱런 가능성이 높은 콘텐츠는 메인 화면, 추천 영역, 캠페인 페이지 등에 더 오래 노출할 후보가 될 수 있습니다.

### 2. 마케팅 우선순위

단기 급상승 콘텐츠와 롱런 가능 콘텐츠는 마케팅 전략이 다를 수 있습니다.

- 단기 급상승형: 초반 바이럴, 신작 홍보
- 롱런형: 장기 노출, 추천 유지, 후속 캠페인

### 3. 구독 유지 관점

단기 인기 콘텐츠가 신규 유입에 도움을 준다면, 롱런 콘텐츠는 사용자가 계속 볼 이유를 만드는 데 기여할 수 있습니다.

### 4. 콘텐츠 전략

롱런 가능성이 높은 콘텐츠의 장르, 유형, 계절, 초반 시청시간 패턴을 보면 향후 콘텐츠 확보나 기획 전략에 참고할 수 있습니다.

---

## E2E 시스템으로 확장한다면

이번 세션의 흐름은 실제 시스템 관점에서 다음처럼 확장할 수 있습니다.

```text
데이터 수집
  ↓
Raw table 적재
  ↓
SQL 정제 / Feature Engineering
  ↓
Model input table 생성
  ↓
모델 학습 / 평가
  ↓
콘텐츠별 롱런 가능성 점수 생성
  ↓
대시보드 / 운영 의사결정
```

실무적으로 저장될 수 있는 결과 테이블 예시는 다음과 같습니다.

```text
title_clean
prediction_date
long_run_probability
predicted_label
threshold
model_version
actual_label_for_validation
```

이런 결과는 이후 대시보드나 운영팀 의사결정에 연결될 수 있습니다.

---

## 실무적으로 주의할 점

### 1. 예측 시점

“첫 주 성과만 보고 롱런을 예측한다”면, 첫 주 이후에야 알 수 있는 정보는 feature로 쓰면 안 됩니다.

### 2. 데이터 범위

이 데이터는 전체 Netflix 카탈로그가 아니라 Top10에 진입한 콘텐츠 중심입니다.

따라서 이 모델은 **전체 콘텐츠 성공 예측 모델이 아니라, Top10 진입 콘텐츠 중 롱런 가능성 예측 모델**에 가깝습니다.

### 3. 모델 성능과 비즈니스 성과는 다르다

F1이나 ROC-AUC가 좋아도 실제 운영에서는 다음을 같이 봐야 합니다.

- 틀렸을 때 비용은 무엇인가?
- False Positive와 False Negative 중 무엇이 더 문제인가?
- 사람이 납득할 수 있는 설명이 가능한가?

### 4. 개인화 추천과는 다르다

이번 모델은 공개 집계 데이터 기반 성과 예측입니다.
개별 사용자 행동 데이터 기반 개인화 추천 모델과는 다릅니다.

---

## 이번 세션에서 특히 볼 포인트

- 예측 문제를 어떻게 정의하는가
- EDA와 상관관계를 어디까지 해석할 수 있는가
- 어떤 feature가 leakage를 일으킬 수 있는가
- train/test split과 3-fold CV의 역할은 어떻게 다른가
- baseline 대비 모델 교체가 실제로 성능을 높였는가
- `RandomizedSearchCV` 튜닝이 성능을 얼마나 바꾸는가
- 어떤 평가 지표를 중점적으로 봐야 하는가
- threshold 선택이 운영 판단을 어떻게 바꾸는가
- 모델 결과를 어떻게 해석하고, 요약형 대시보드로 연결할 수 있는가

---

## 회고 질문

이번 회차는 코드를 직접 작성하기보다 데모를 보고 개념을 정리하는 시간이므로, 회고 질문도 개념 확인형으로 둡니다.

### Q1. 문제 정의

이번 모델은 어떤 문제에 더 가깝나요?

- A. 전체 Netflix 콘텐츠가 성공할지 예측한다.
- B. Top10에 이미 진입한 콘텐츠가 롱런할지 예측한다.
- C. 콘텐츠가 몇 주 동안 Top10에 머무를지 정확한 숫자를 예측한다.

확인 포인트: 이번 target은 `long_run_flag`이고, 문제 유형은 분류입니다.

### Q2. 예측 시점

“첫 Top10 진입 주차 기준으로 예측한다”는 말의 의미로 맞는 것은 무엇인가요?

- A. 첫 주차 이후의 성과는 feature로 쓰지 않는다.
- B. 전체 Top10 기간을 다 본 뒤 평균 성과를 feature로 쓴다.
- C. `max_cumulative_weeks`를 feature로 넣어도 된다.

확인 포인트: 예측 시점에 알 수 없는 정보는 feature로 쓰면 leakage가 됩니다.

### Q3. Leakage

다음 중 leakage 가능성이 가장 큰 feature는 무엇인가요?

- A. `first_week_rank`
- B. `primary_genre`
- C. `max_cumulative_weeks`

확인 포인트: `long_run_flag`를 만드는 기준과 직접 연결된 사후 정보는 위험합니다.

### Q4. 상관관계 해석

상관관계나 feature importance를 볼 때 가장 안전한 해석은 무엇인가요?

- A. 이 feature가 롱런의 원인이다.
- B. 이 feature는 롱런 여부와 관련이 있어 보인다.
- C. 이 feature만 있으면 롱런을 완벽히 설명할 수 있다.

확인 포인트: 상관관계와 feature importance는 인과를 증명하지 않습니다.

### Q5. 검증 구조

`RandomizedSearchCV(cv=3)`에서 `cv=3`의 의미로 맞는 것은 무엇인가요?

- A. test data를 3번 반복해서 평가한다.
- B. train data 내부를 3개 fold로 나눠 파라미터 조합을 비교한다.
- C. 전체 데이터를 3개 모델에 나눠 학습한다.

확인 포인트: test data는 최종 평가용으로 남겨두고, CV는 train data 내부에서 수행합니다.

### Q6. Precision / Recall

롱런 후보를 놓치지 않는 것이 가장 중요하다면 더 우선해서 볼 지표는 무엇인가요?

- A. Precision
- B. Recall
- C. Accuracy만 보면 충분하다.

확인 포인트: 실제 롱런 콘텐츠를 얼마나 잡아냈는지는 Recall과 연결됩니다.

### Q7. Threshold

Threshold를 높이면 일반적으로 어떤 변화가 생기기 쉬운가요?

- A. 더 많은 콘텐츠를 롱런 후보로 잡는다.
- B. 더 적고 확실한 콘텐츠만 롱런 후보로 잡는다.
- C. 모델의 feature가 자동으로 바뀐다.

확인 포인트: threshold는 모델 자체가 아니라 확률을 label로 바꾸는 운영 기준입니다.

### Q8. 대시보드 결과 해석

HTML 요약 대시보드에서 `long_run_probability`는 무엇으로 해석하는 것이 가장 적절한가요?

- A. 롱런의 원인을 설명하는 값
- B. 후보 우선순위를 보기 위한 모델 점수
- C. 실제 시청시간과 같은 원본 데이터

확인 포인트: 확률 점수는 운영 판단을 돕는 신호이지, 원인 설명은 아닙니다.

---

## 회고 질문 정답

| 문항 | 정답 | 핵심 이유 |
| --- | --- | --- |
| Q1 | B | 이번 모델은 Top10에 이미 진입한 콘텐츠 중 롱런 여부를 예측한다. |
| Q2 | A | 첫 진입 주차 기준 예측이므로 이후 성과는 feature로 쓰면 안 된다. |
| Q3 | C | `max_cumulative_weeks`는 `long_run_flag` 생성 기준과 직접 연결된 사후 정보다. |
| Q4 | B | 상관관계와 feature importance는 관련성을 보여줄 수 있지만 인과를 증명하지 않는다. |
| Q5 | B | `cv=3`은 train data 내부를 3개 fold로 나눠 파라미터 조합을 비교한다는 뜻이다. |
| Q6 | B | 실제 롱런 콘텐츠를 놓치지 않는 정도는 Recall로 본다. |
| Q7 | B | threshold를 높이면 더 확실한 콘텐츠만 롱런 후보로 잡는 경향이 있다. |
| Q8 | B | `long_run_probability`는 후보 우선순위를 보기 위한 모델 점수다. |

---

## 참고 링크

- [scikit-learn Common pitfalls and recommended practices](https://scikit-learn.org/stable/common_pitfalls.html)
- [scikit-learn RandomizedSearchCV](https://scikit-learn.org/stable/modules/generated/sklearn.model_selection.RandomizedSearchCV.html)
- [scikit-learn Hyperparameter tuning](https://scikit-learn.org/stable/modules/grid_search.html)
- [scikit-learn Metrics and scoring](https://scikit-learn.org/stable/modules/model_evaluation.html)
