# Week 2 실습 안내

Week 2는 Kaggle의 `The Movies Dataset`을 사용해 ETL의 `T`, 즉 Transform 과정을 실습합니다.

핵심은 분석용 결과표를 바로 만드는 것이 아니라, 원본 데이터를 확인하고 정제해서 이후 DB 적재나 추가 분석에 사용할 수 있는 신뢰성 있는 테이블을 만드는 것입니다.

## 폴더 구조

```text
week2/
├── docs/
│   └── README.md
├── src/
│   ├── download_dataset.py
│   ├── w2_1.ipynb
│   ├── w2_1_skeleton.ipynb
│   ├── w2_2.ipynb
│   └── w2_2_skeleton.ipynb
└── data/
    ├── raw/       # Kaggle 원본 CSV
    └── output/    # 노트북 실행으로 생성한 정제/산출 CSV
```

`week2/data/`는 GitHub에 올리지 않습니다. 원본 데이터는 다운로드 스크립트로 다시 받을 수 있고, 산출물은 노트북 실행으로 다시 만들 수 있습니다.

## 데이터 다운로드

루트 경로에서 아래 명령을 실행합니다.

```bash
python week2/src/download_dataset.py
```

다운로드 후 원본 CSV는 아래 경로에 저장됩니다.

```text
week2/data/raw/
```

예상 파일:

```text
credits.csv
keywords.csv
links.csv
links_small.csv
movies_metadata.csv
ratings.csv
ratings_small.csv
```

노트북에서 생성하는 결과물은 아래 경로에 저장합니다.

```text
week2/data/output/
```

## 실습 2-1: 기본 Transform

```text
week2/src/w2_1.ipynb
```

목표는 raw 데이터를 그대로 저장하거나 분석하지 않고, 저장 전에 기본적인 품질 점검과 정제를 수행하는 것입니다.

주요 내용:

- raw 데이터 구조 확인
- 사용할 컬럼 선택
- 제외한 컬럼 예시와 제외 이유 확인
- 컬럼명 최소 표준화
- 자료형 변환
- `release_year` 파생 컬럼 생성
- 결측치 점검과 처리
- 중복 점검과 제거
- 논리적으로 이상한 값 점검과 처리
- DB 적재 전 clean table 생성

결과 파일:

```text
week2/data/output/movies_clean_for_load.csv
```

## 실습 2-1 스켈레톤

```text
week2/src/w2_1_skeleton.ipynb
```

`w2_1.ipynb`와 같은 흐름이지만 핵심 코드 일부가 `TODO`로 비어 있습니다. 수업 중 직접 채워보는 용도입니다.

## 실습 2-2: 보너스 Transform

```text
week2/src/w2_2.ipynb
```

목표는 CSV 안에 문자열 형태로 들어 있는 리스트 데이터를 관계형 테이블에 가까운 구조로 바꾸는 것입니다.

예를 들어 영화 1행 안에 여러 배우, 여러 키워드가 문자열로 들어 있으면 바로 조인하거나 집계하기 어렵습니다. 이를 `영화-키워드`, `영화-배우`, `영화-감독`처럼 관계 1개당 1행인 테이블로 바꾸면 이후 분석과 적재가 쉬워집니다.

주요 내용:

- `credits.csv`, `keywords.csv` 원본 확인
- 영화 ID 기준으로 데이터 맞추기
- 문자열 리스트 파싱
- `keywords`에서 `movie_keywords` 테이블 만들기
- `cast`에서 `movie_cast` 테이블 만들기
- `crew`에서 `movie_crew`, `directors` 테이블 만들기
- 키워드별 영화 수 확인
- 키워드별 평균 평점 확인
- 배우-키워드 관계 확인
- 감독-키워드 관계 확인

핵심 메시지:

```text
영화 1행 안에 여러 값이 들어 있는 구조
→ 관계 1개당 1행인 테이블
```

## 실습 2-2 스켈레톤

```text
week2/src/w2_2_skeleton.ipynb
```

`w2_2.ipynb`와 같은 흐름이지만 핵심 Transform 코드 일부가 `TODO`로 비어 있습니다.

## 권장 실행 순서

1. 루트 README를 참고해 가상환경을 만들고 라이브러리를 설치합니다.
2. `python week2/src/download_dataset.py`로 데이터를 다운로드합니다.
3. `week2/src/w2_1.ipynb`를 실행해 clean table을 만듭니다.
4. 필요하면 `week2/src/w2_1_skeleton.ipynb`로 같은 흐름을 직접 채워봅니다.
5. `week2/src/w2_2.ipynb`로 보너스 Transform 실습을 진행합니다.
6. 필요하면 `week2/src/w2_2_skeleton.ipynb`로 심화 내용을 직접 채워봅니다.
