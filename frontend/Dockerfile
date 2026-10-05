FROM python:3.12-slim
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    GRADIO_ANALYTICS_ENABLED=False
RUN useradd --create-home --uid 10001 appuser
WORKDIR /app
# constraints.txt pins every transitive package (pip freeze of a known-good build) so rebuilds are reproducible.
COPY requirements.txt constraints.txt ./
RUN pip install --no-cache-dir -r requirements.txt -c constraints.txt
COPY app.py .
USER appuser
EXPOSE 7860
HEALTHCHECK --interval=10s --timeout=3s --start-period=20s --retries=5 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:7860/')"
CMD ["python", "app.py"]
