# Use official Python base image
FROM python:3.11-slim


# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    FLASK_APP=app.py

# Set working directory
WORKDIR /app

# opy dependencies file first to leverage Docker layer cache
COPY requirements.txt .

# Install dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application files, copies everything into container
COPY . .

# Expose port 80 for the Flask app, app will serve traffic on port 80
EXPOSE 80

# Run flask aplication, main cmmand that runs when container starts
ENV FLASK_APP=app.py
CMD ["flask", "run", "--host=0.0.0.0", "--port=80"]
