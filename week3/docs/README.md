# Week 3 실습 안내

Week 3는 PostgreSQL에 데이터를 적재한 뒤, SQL로 조회하고 분석하는 흐름을 실습합니다.

이번 주차의 핵심은 CSV를 바로 보는 것이 아니라, 실습용 데이터베이스를 먼저 준비하고 그 위에서 `CTE`, `Window Function` 같은 SQL 문법을 익히는 것입니다.

## 폴더 구조

```text
week3/
├── docs/
│   ├── README.md
│   └── notes.md
├── src/
│   ├── 3_1/
│   │   └── 1_cte_window_cancer.sql
│   └── setup/
│       ├── README.md
│       └── run.py
└── data/
    ├── cancer/
    │   └── The_Cancer_data_1500_V2.csv
    └── netflix/
        ├── all_weeks_global_raw.csv
        ├── mart_global_final.csv
        └── netflix_titles_raw.csv
```

Week 3는 실습에 필요한 CSV가 이미 `week3/data/`에 들어 있습니다.

따라서 별도의 다운로드 스크립트 없이 바로 DB 셋업을 진행하면 됩니다.

## 사전 준비

루트 경로에서 가상환경과 라이브러리를 먼저 준비합니다.

```bash
python -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
pip install -r requirements.txt
```

Windows PowerShell에서는 가상환경 활성화 명령이 다릅니다.

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
pip install -r requirements.txt
```

추가로 로컬에 PostgreSQL 서버가 실행 중이어야 합니다.

## DB 셋업

DB 초기화 스크립트는 아래 파일입니다.

```text
week3/src/setup/run.py
```

실행 전에 `run.py` 상단의 `DB_CONFIG`를 자신의 PostgreSQL 환경에 맞게 수정합니다.

```python
DB_CONFIG = {
    "host": "localhost",
    "port": 5432,
    "user": "postgres",
    "password": "postgres",
}
```

수정 후 루트 경로에서 아래 명령을 실행합니다.

```bash
python week3/src/setup/run.py
```

이 스크립트는 자동으로 아래 작업을 수행합니다.

- `dataschool_study` 데이터베이스를 새로 생성
- 실습용 테이블 4개 생성
- 인덱스 생성
- CSV 데이터를 각 테이블에 적재

생성되는 테이블:

```text
cancer_data
netflix_titles
netflix_all_weeks_global
netflix_mart_global
```

주의:

- 이 스크립트는 실행할 때 기존 `dataschool_study` DB를 `DROP`한 뒤 다시 만듭니다.
- 이미 만들어 둔 실습 결과가 있다면 다시 초기화됩니다.

## 접속 확인

DB 셋업이 끝나면 PostgreSQL 클라이언트에서 `dataschool_study` DB에 접속해 테이블이 생성되었는지 확인합니다.

예를 들어 VS Code PostgreSQL 확장을 쓰는 경우:

- host: `localhost`
- port: `5432`
- database: `dataschool_study`
- user: `postgres`
- password: `run.py`에 넣은 값

`notes.md` 기준으로, 서버 입력란에는 `localhost:5432` 대신 `localhost`만 넣는 것을 권장합니다.

## 실습 3-1: CTE와 Window Function 워밍업

```text
week3/src/3_1/1_cte_window_cancer.sql
```

이 파일은 `cancer_data` 테이블을 사용해 `CTE (WITH)`와 `Window Function`의 기본 감각을 익히는 예제 모음입니다.

주요 내용:

- `WITH`로 중간 결과를 나눠 쓰기
- `CASE WHEN`으로 라벨 컬럼 만들기
- `RANK() OVER (ORDER BY ...)`로 전체 순위 붙이기
- `PARTITION BY`로 그룹별 순위 계산하기
- `AVG() OVER (...)`로 그룹 평균과 현재 행 비교하기
- `CTE + Window Function`을 조합해 상위 N개만 보기

핵심 메시지:

```text
GROUP BY는 결과를 요약하고
WINDOW FUNCTION은 원본 행을 유지한 채 비교 정보를 붙인다
```

## 권장 실행 순서

1. 루트 README를 참고해 가상환경을 만들고 라이브러리를 설치합니다.
2. 로컬 PostgreSQL 서버가 실행 중인지 확인합니다.
3. `week3/src/setup/run.py`의 `DB_CONFIG`를 자신의 환경에 맞게 수정합니다.
4. `python week3/src/setup/run.py`를 실행해 `dataschool_study` DB와 테이블을 생성합니다.
5. SQL 클라이언트로 `dataschool_study`에 접속해 테이블이 잘 들어왔는지 확인합니다.
6. `week3/src/3_1/1_cte_window_cancer.sql`을 순서대로 실행하며 `CTE`, `Window Function` 예제를 확인합니다.
