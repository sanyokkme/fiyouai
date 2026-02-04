FROM python:3.10-slim

# Вимикає буферизацію, щоб логи з'являлися миттєво
ENV PYTHONUNBUFFERED=1 

WORKDIR /app

RUN apt-get update && apt-get install -y \
    libjpeg-dev \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . /app

EXPOSE 8000

# Для розробки вона буде перезаписана вашим docker-compose.yaml
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]