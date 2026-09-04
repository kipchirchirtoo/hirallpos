import logging
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import settings
from app.db.session import engine, Base, SessionLocal
from app.db.init_db import init_db
from app.db.base import *  # Load all models
from app.api.v1.api import api_router

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("hirall-pos")

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: Ensure tables exist and default seeds are populated
    logger.info("Initializing database tables and module seeds...")
    try:
        Base.metadata.create_all(bind=engine)
        db = SessionLocal()
        init_db(db)
        db.close()
        logger.info("Database initialized successfully.")
    except Exception as e:
        logger.warning(f"Could not connect to database on startup (will retry on requests): {e}")
    yield
    # Shutdown
    logger.info("Shutting down Hirall POS API.")

app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    openapi_url=f"{settings.API_V1_STR}/openapi.json",
    lifespan=lifespan
)

# CORS configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.BACKEND_CORS_ORIGINS or ["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# API Routers
app.include_router(api_router, prefix=settings.API_V1_STR)

@app.get("/health")
def health_check():
    return {
        "status": "healthy",
        "service": settings.PROJECT_NAME,
        "version": settings.VERSION,
        "environment": settings.ENVIRONMENT
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app.main:app", host="0.0.0.0", port=8000, reload=True)
