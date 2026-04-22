# Dataschool Study

데이터 스쿨 실습 자료를 정리하는 저장소입니다.

루트 README에는 모든 주차에서 공통으로 사용하는 실행 환경과 기본 사용법만 정리합니다. 각 주차별 실습 설명, 데이터 준비 방법, 노트북 실행 순서는 주차별 문서에서 확인합니다.

## 현재 공개 대상

```text
.
├── README.md
├── requirements.txt
└── week2/
    ├── docs/
    │   └── README.md
    └── src/
```

`week1/`은 현재 GitHub에 올리지 않는 로컬 작업 폴더로 관리합니다.

## 환경 세팅

Python 가상환경을 만든 뒤 필요한 라이브러리를 설치합니다.

```bash
python -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
```

Windows PowerShell에서는 가상환경 활성화 명령이 다릅니다.

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
```

## Jupyter 실행

```bash
jupyter notebook
```

또는 JupyterLab을 사용할 수 있습니다.

```bash
jupyter lab
```

## 주차별 문서

- [Week 2 실습 안내](week2/docs/README.md)

## 공통 작성 가이드

- [실습 노트북 작성 가이드](docs/notebook_authoring_guide.md)

## 데이터 관리 원칙

실습용 원본 데이터와 노트북 실행 결과물은 GitHub에 올리지 않습니다.

이유:

- 원본 CSV 파일은 용량이 커질 수 있습니다.
- 데이터는 다운로드 스크립트로 다시 받을 수 있습니다.
- 결과물은 노트북 실행으로 다시 만들 수 있습니다.
- GitHub에는 코드, 노트북, 문서 중심으로 남기는 편이 관리하기 쉽습니다.

각 주차의 데이터 다운로드와 저장 위치는 주차별 문서에서 확인합니다.

## 자주 쓰는 명령

가상환경 활성화:

```bash
source .venv/bin/activate
```

라이브러리 설치:

```bash
pip install -r requirements.txt
```

Jupyter 실행:

```bash
jupyter notebook
```
