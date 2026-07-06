FROM python:3.12-slim
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends pulseaudio-utils && rm -rf /var/lib/apt/lists/*
RUN pip install --no-cache-dir flask
COPY app.py index.html ./
CMD ["python", "app.py"]
