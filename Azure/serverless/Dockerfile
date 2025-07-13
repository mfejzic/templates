# Use official Python base image
FROM python:3.11-slim

# Set environment variables (disable pyc, enable unbuffered output)
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Set working directory
WORKDIR /app

# Copy dependencies file first to leverage Docker layer cache
COPY requirements.txt .

# Install dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application files (everything in context)
COPY . .

# Add Cosmos DB environment variables permanently, key is subject to change
ENV COSMOS_ENDPOINT=""
ENV COSMOS_KEY=""        
ENV COSMOS_DB_NAME=""
ENV COSMOS_CONTAINER_NAME=""

# Expose port for Flask app
EXPOSE 80

# Set Flask app (no need to repeat FLASK_APP twice)
ENV FLASK_APP=app.py

# Run Flask application - use this for testing
CMD ["flask", "run", "--host=0.0.0.0", "--port=80"]

# for prodcution use this one and add gunicorn to requirements.txt
# CMD ["gunicorn", "-b", "0.0.0.0:80", "app:app"]

