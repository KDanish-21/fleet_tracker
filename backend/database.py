import ssl
import asyncpg
from config import settings

pool: asyncpg.Pool = None
_initialized = False


def _get_ssl():
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    return ctx


async def get_pool() -> asyncpg.Pool:
    """Get or create the connection pool (lazy init)."""
    global pool, _initialized
    if pool is None:
        pool = await asyncpg.create_pool(
            settings.DATABASE_URL,
            min_size=1,
            max_size=5,
            ssl=_get_ssl(),
            command_timeout=15,
        )
    if not _initialized:
        async with pool.acquire() as conn:
            await conn.execute("""
                CREATE TABLE IF NOT EXISTS users (
                    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                    name VARCHAR(255) NOT NULL,
                    email VARCHAR(255) UNIQUE NOT NULL,
                    phone VARCHAR(50) DEFAULT '',
                    hashed_password VARCHAR(255) NOT NULL,
                    created_at TIMESTAMPTZ DEFAULT NOW()
                );
            """)
        _initialized = True
        print("Database connected and tables ready.")
    return pool


async def close_db():
    """Close the connection pool."""
    global pool
    if pool:
        await pool.close()
        pool = None
        print("Database connection closed.")
