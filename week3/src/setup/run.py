"""
PostgreSQL 데이터베이스 및 데이터 초기화 스크립트
아래 DB_CONFIG를 수정하면 자동으로 실행됨
"""

import sys
import psycopg2
import pandas as pd
from pathlib import Path

# ========================================
# 데이터베이스 연결 설정 (여기서 수정)
# ========================================
DB_CONFIG = {
    "host": "localhost",
    "port": 5432,
    "user": "postgres",
    "password": "postgres",
}

# 데이터 경로
BASE_PATH = Path(__file__).parent.parent.parent / "data"

CANCER_DATA_PATH = BASE_PATH / "cancer" / "The_Cancer_data_1500_V2.csv"
NETFLIX_DATA_PATHS = {
    "netflix_titles": BASE_PATH / "netflix" / "netflix_titles_raw.csv",
    "netflix_all_weeks": BASE_PATH / "netflix" / "all_weeks_global_raw.csv",
    "netflix_mart": BASE_PATH / "netflix" / "mart_global_final.csv",
}

# SQL 스키마
SQL_SCHEMA = """
DROP TABLE IF EXISTS netflix_mart_global CASCADE;
DROP TABLE IF EXISTS netflix_all_weeks_global CASCADE;
DROP TABLE IF EXISTS netflix_titles CASCADE;
DROP TABLE IF EXISTS cancer_data CASCADE;

CREATE TABLE cancer_data (
    id SERIAL PRIMARY KEY,
    age INTEGER,
    gender INTEGER,
    bmi NUMERIC,
    smoking INTEGER,
    genetic_risk INTEGER,
    physical_activity NUMERIC,
    alcohol_intake NUMERIC,
    cancer_history INTEGER,
    diagnosis INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE netflix_titles (
    id SERIAL PRIMARY KEY,
    show_id VARCHAR(10) UNIQUE NOT NULL,
    type VARCHAR(50),
    title VARCHAR(500),
    director TEXT,
    "cast" TEXT,
    country VARCHAR(255),
    date_added VARCHAR(50),
    release_year INTEGER,
    rating VARCHAR(20),
    duration VARCHAR(50),
    listed_in TEXT,
    description TEXT,
    duration_value INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE netflix_all_weeks_global (
    id SERIAL PRIMARY KEY,
    week DATE,
    category VARCHAR(50),
    weekly_rank INTEGER,
    show_title VARCHAR(500),
    season_title VARCHAR(255),
    weekly_hours_viewed BIGINT,
    runtime NUMERIC,
    weekly_views BIGINT,
    cumulative_weeks_in_top_10 INTEGER,
    is_staggered_launch BOOLEAN,
    episode_launch_details TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE netflix_mart_global (
    id SERIAL PRIMARY KEY,
    week_date DATE,
    month_num INTEGER,
    season VARCHAR(50),
    title_clean VARCHAR(500),
    show_title VARCHAR(500),
    weekly_rank_num INTEGER,
    weekly_hours_viewed_num BIGINT,
    cumulative_weeks_in_top_10_num INTEGER,
    type_clean VARCHAR(50),
    genre TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_cancer_diagnosis ON cancer_data(diagnosis);
CREATE INDEX idx_cancer_age ON cancer_data(age);
CREATE INDEX idx_netflix_titles_title ON netflix_titles(title);
CREATE INDEX idx_netflix_titles_type ON netflix_titles(type);
CREATE INDEX idx_netflix_all_weeks_date ON netflix_all_weeks_global(week);
CREATE INDEX idx_netflix_all_weeks_title ON netflix_all_weeks_global(show_title);
CREATE INDEX idx_netflix_mart_date ON netflix_mart_global(week_date);
CREATE INDEX idx_netflix_mart_title ON netflix_mart_global(show_title);
"""


def to_int(value):
    """빈값이나 문자열이 섞여 있어도 안전하게 정수로 변환한다."""
    if value is None or pd.isna(value):
        return None
    text = str(value).strip()
    if not text:
        return None
    try:
        return int(float(text))
    except (TypeError, ValueError):
        return None


def to_float(value):
    if value is None or pd.isna(value):
        return None
    text = str(value).strip()
    if not text:
        return None
    try:
        return float(text)
    except (TypeError, ValueError):
        return None


def to_bool(value):
    if value is None or pd.isna(value):
        return False
    if isinstance(value, bool):
        return value
    text = str(value).strip().lower()
    return text in {"true", "1", "t", "yes", "y"}


def setup_database():
    """데이터베이스 생성 및 테이블 초기화"""
    print("[1/2] 데이터베이스 생성 중...")
    conn = psycopg2.connect(**DB_CONFIG)
    conn.autocommit = True

    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT pg_terminate_backend(pg_stat_activity.pid)
            FROM pg_stat_activity
            WHERE pg_stat_activity.datname = 'dataschool_study'
              AND pid <> pg_backend_pid()
        """
        )

        cur.execute("DROP DATABASE IF EXISTS dataschool_study")
        cur.execute("CREATE DATABASE dataschool_study")

    conn.close()

    print("[2/2] 테이블 생성 중...")
    db_config = DB_CONFIG.copy()
    db_config["database"] = "dataschool_study"
    conn = psycopg2.connect(**db_config)

    with conn.cursor() as cur:
        cur.execute(SQL_SCHEMA)

    conn.commit()
    conn.close()
    print("✓ 데이터베이스 및 테이블 생성 완료")


def load_cancer_data(conn):
    print("[1/4] Cancer 데이터 임포트 중...")
    df = pd.read_csv(CANCER_DATA_PATH, encoding="utf-8")

    with conn.cursor() as cur:
        for _, row in df.iterrows():
            cur.execute(
                """
                INSERT INTO cancer_data 
                (age, gender, bmi, smoking, genetic_risk, physical_activity, 
                 alcohol_intake, cancer_history, diagnosis)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
            """,
                (
                    to_int(row["Age"]),
                    to_int(row["Gender"]),
                    to_float(row["BMI"]),
                    to_int(row["Smoking"]),
                    to_int(row["GeneticRisk"]),
                    to_float(row["PhysicalActivity"]),
                    to_float(row["AlcoholIntake"]),
                    to_int(row["CancerHistory"]),
                    to_int(row["Diagnosis"]),
                ),
            )
    conn.commit()
    print(f"✓ Cancer: {len(df):,} 행 임포트 완료")


def load_netflix_titles(conn):
    print("[2/4] Netflix Titles 임포트 중...")
    df = pd.read_csv(NETFLIX_DATA_PATHS["netflix_titles"], encoding="mac-roman")

    with conn.cursor() as cur:
        for _, row in df.iterrows():
            cur.execute(
                """
                INSERT INTO netflix_titles 
                (show_id, type, title, director, "cast", country, date_added,
                 release_year, rating, duration, listed_in, description, duration_value)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                ON CONFLICT (show_id) DO NOTHING
            """,
                (
                    str(row.get("show_id", "")),
                    str(row.get("type", "")),
                    str(row.get("title", "")),
                    str(row.get("director", "")),
                    str(row.get("cast", "")),
                    str(row.get("country", "")),
                    str(row.get("date_added", "")),
                    to_int(row["release_year"]),
                    str(row.get("rating", "")),
                    str(row.get("duration", "")),
                    str(row.get("listed_in", "")),
                    str(row.get("description", "")),
                    to_int(row["duration_value"]),
                ),
            )
    conn.commit()
    print(f"✓ Netflix Titles: {len(df):,} 행 임포트 완료")


def load_netflix_all_weeks(conn):
    print("[3/4] Netflix All Weeks 임포트 중...")
    df = pd.read_csv(NETFLIX_DATA_PATHS["netflix_all_weeks"], encoding="cp1252")
    df = df.fillna("")

    with conn.cursor() as cur:
        for _, row in df.iterrows():
            cur.execute(
                """
                INSERT INTO netflix_all_weeks_global 
                (week, category, weekly_rank, show_title, season_title,
                 weekly_hours_viewed, runtime, weekly_views, 
                 cumulative_weeks_in_top_10, is_staggered_launch, episode_launch_details)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            """,
                (
                    row["week"],
                    str(row.get("category", "")),
                    to_int(row["weekly_rank"]),
                    str(row.get("show_title", "")),
                    str(row.get("season_title", "")),
                    to_int(row["weekly_hours_viewed"]),
                    to_float(row["runtime"]),
                    to_int(row["weekly_views"]),
                    to_int(row["cumulative_weeks_in_top_10"]),
                    to_bool(row["is_staggered_launch"]),
                    str(row.get("episode_launch_details", "")),
                ),
            )

    print(f"Netflix All Weeks: {len(df):,} 행 임포트 완료")


def load_netflix_mart(conn):
    print("[4/4] Netflix Mart 임포트 중...")
    df = pd.read_csv(NETFLIX_DATA_PATHS["netflix_mart"], encoding="utf-8")

    with conn.cursor() as cur:
        for _, row in df.iterrows():
            cur.execute(
                """
                INSERT INTO netflix_mart_global 
                (week_date, month_num, season, title_clean, show_title,
                 weekly_rank_num, weekly_hours_viewed_num, 
                 cumulative_weeks_in_top_10_num, type_clean, genre)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            """,
                (
                    row["week_date"],
                    to_int(row["month_num"]),
                    str(row.get("season", "")),
                    str(row.get("title_clean", "")),
                    str(row.get("show_title", "")),
                    to_int(row["weekly_rank_num"]),
                    to_int(row["weekly_hours_viewed_num"]),
                    to_int(row["cumulative_weeks_in_top_10_num"]),
                    str(row.get("type_clean", "")),
                    str(row.get("genre", "")),
                ),
            )
    conn.commit()
    print(f"✓ Netflix Mart: {len(df):,} 행 임포트 완료")


def main():
    print("=" * 50)
    print("PostgreSQL 데이터베이스 초기화")
    print("=" * 50)

    try:
        setup_database()

        print("\n" + "=" * 50)
        print("데이터 임포트")
        print("=" * 50)

        db_config = DB_CONFIG.copy()
        db_config["database"] = "dataschool_study"
        conn = psycopg2.connect(**db_config)

        load_cancer_data(conn)
        load_netflix_titles(conn)
        load_netflix_all_weeks(conn)
        load_netflix_mart(conn)

        with conn.cursor() as cur:
            cur.execute("SELECT COUNT(*) FROM cancer_data")
            cancer_count = cur.fetchone()[0]
            cur.execute("SELECT COUNT(*) FROM netflix_titles")
            titles_count = cur.fetchone()[0]
            cur.execute("SELECT COUNT(*) FROM netflix_all_weeks_global")
            all_weeks_count = cur.fetchone()[0]
            cur.execute("SELECT COUNT(*) FROM netflix_mart_global")
            mart_count = cur.fetchone()[0]
            total = cancer_count + titles_count + all_weeks_count + mart_count

        conn.close()

        print(f"\n✓ 총 {total:,} 행 임포트 완료!")
        print("\n" + "=" * 50)
        print("✓ 모든 작업 완료!")
        print("=" * 50)
    except Exception as e:
        print(f"\n✗ 오류 발생: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
