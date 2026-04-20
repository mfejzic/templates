# Use Python base image
FROM python:3.9-slim

# Set working directory
WORKDIR /app

# Copy requirements first
COPY requirements.txt .

# Install dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy app code
COPY . /app

# Expose port
EXPOSE 5000

# Run application
CMD ["python", "app.py"]