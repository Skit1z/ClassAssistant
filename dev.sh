#!/bin/bash

# ClassFox Development Startup Script for macOS
# This script sets up and starts the development environment

echo "🚀 Starting ClassFox Development Environment..."

# Function to cleanup processes
cleanup_processes() {
    echo "🧹 Cleaning up old processes..."
    pkill -f "uvicorn.*main:app" 2>/dev/null || true
    pkill -f "tauri.*dev" 2>/dev/null || true
    lsof -ti:8765 | xargs kill -9 2>/dev/null || true
    echo "✅ Cleanup complete"
}

# Start the backend
start_backend() {
    echo "🔧 Starting FastAPI backend..."
    cd api-service

    # Use uv to run the backend
    uv run uvicorn main:app --host 127.0.0.1 --port 8765 --reload &
    BACKEND_PID=$!
    echo "✅ Backend started on http://127.0.0.1:8765 (PID: $BACKEND_PID)"

    cd ..
}

# Start the frontend
start_frontend() {
    echo "🎨 Starting Tauri frontend..."
    cd app-ui

    # Start Tauri development mode
    npm run tauri dev &
    FRONTEND_PID=$!
    echo "✅ Frontend started (PID: $FRONTEND_PID)"

    cd ..
}

# Function to handle script exit
cleanup_on_exit() {
    echo "🛑 Shutting down..."
    if [ ! -z "$BACKEND_PID" ]; then
        kill $BACKEND_PID 2>/dev/null || true
    fi
    if [ ! -z "$FRONTEND_PID" ]; then
        kill $FRONTEND_PID 2>/dev/null || true
    fi
    cleanup_processes
    exit 0
}

# Set up signal handlers
trap cleanup_on_exit INT TERM

# Main setup process
cleanup_processes

echo "⚡ Starting services..."
start_backend

# Wait for backend to be ready
echo "⏳ Waiting for backend to be ready..."
sleep 3

start_frontend

echo ""
echo "🎉 Development environment is running!"
echo "📍 Backend: http://127.0.0.1:8765"
echo "📍 Frontend: Tauri window should appear shortly"
echo "⚡ Press Ctrl+C to stop all services"
echo ""

# Keep the script running
wait