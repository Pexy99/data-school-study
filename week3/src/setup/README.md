# Database Setup

데이터베이스를 초기화하고 데이터를 임포트합니다.

## 빠른 시작

```bash
python week3/src/setup/run.py
```

## 환경 설정

`run.py` 상단의 `DB_CONFIG`를 수정해서 DB 연결 정보 변경:

```python
DB_CONFIG = {
    "host": "localhost",
    "port": 5432,
    "user": "postgres",
    "password": "postgres",  # ← 비밀번호 수정
}
```

## 처리 과정

`run.py` 실행 시 자동으로:

1. **DB 생성**: `dataschool_study` 데이터베이스 생성
2. **테이블 생성**: 4개 테이블 및 인덱스 생성
   - cancer_data
   - netflix_titles
   - netflix_all_weeks_global
   - netflix_mart_global
3. **데이터 임포트**: CSV에서 모든 데이터 로드
   - Cancer: 1,500행
   - Netflix Titles: ~8,800행
   - Netflix All Weeks: ~20,000행
   - Netflix Mart: ~20,000행

## 파일 구조

```
week3/src/setup/
├── run.py       ← 이 파일만 실행
└── README.md    ← 이 문서
```
