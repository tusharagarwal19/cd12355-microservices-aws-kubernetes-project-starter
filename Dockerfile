# Use an official Python runtime as a parent image
FROM python:3.9-slim

# Set the working directory in the container
WORKDIR /app

# Copy the requirements.txt file from the analytics directory
COPY ./analytics/requirements.txt /app/requirements.txt

# Install any necessary dependencies
RUN pip install --upgrade pip setuptools wheel
RUN pip install -r /app/requirements.txt

# Copy the entire analytics directory into the working directory /app in the container
COPY ./analytics /app

# Expose the port the app runs on
EXPOSE 5153

# Set environment variables (modify if needed)
ENV DB_USERNAME=myuser
ENV DB_PASSWORD=mypassword
ENV DB_HOST=127.0.0.1
ENV DB_PORT=5433
ENV DB_NAME=mydatabase

# Run the application
CMD ["python", "app.py"]
