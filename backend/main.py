from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from config import settings
from gps51.client import gps51
from database import close_db
from routes.vehicles import router as vehicles_router
from routes.location import router as location_router
from routes.reports import router as reports_router
from routes.auth import router as auth_router


app = FastAPI(
    title="GPS51 Fleet Tracker API",
    description="FastAPI backend connecting GPS51 to the fleet dashboard",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.origins,
    allow_origin_regex=settings.ALLOWED_ORIGIN_REGEX,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Routers
app.include_router(vehicles_router)
app.include_router(location_router)
app.include_router(reports_router)
app.include_router(auth_router)


@app.on_event("startup")
async def startup():
    print("Connecting to GPSPOS API...")
    try:
        await gps51.login()
        print("GPSPOS connected successfully.")
    except Exception as e:
        print(f"WARNING: GPSPOS login failed on startup: {e}")


@app.on_event("shutdown")
async def shutdown():
    await gps51.close()
    await close_db()
    print("Shutdown complete.")


@app.get("/")
async def root():
    return {"status": "ok", "message": "GPS51 Fleet Tracker API is running"}


@app.get("/health")
async def health():
    from database import get_pool

    db_connected = False
    db_error = None
    try:
        pool = await get_pool()
        async with pool.acquire() as conn:
            await conn.fetchval("SELECT 1")
        db_connected = True
    except Exception as e:
        db_error = str(e)

    return {
        "status": "ok",
        "gpspos_connected": gps51._logged_in,
        "gpspos_server": gps51.base_url,
        "db_connected": db_connected,
        "db_error": db_error,
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="127.0.0.1", port=settings.PORT, reload=True)
