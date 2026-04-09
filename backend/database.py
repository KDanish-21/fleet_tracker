import ssl
import asyncpg
from config import settings

pool: asyncpg.Pool = None
_initialized = False


async def get_pool() -> asyncpg.Pool:
    """Get or create the connection pool (lazy init)."""
    global pool, _initialized
    if pool is None:
        # Strip sslmode from URL (asyncpg handles SSL via parameter, not URL)
        dsn = settings.DATABASE_URL.split("?")[0]

        ssl_ctx = ssl.create_default_context()
        ssl_ctx.check_hostname = False
        ssl_ctx.verify_mode = ssl.CERT_NONE

        try:
            pool = await asyncpg.create_pool(
                dsn,
                min_size=1,
                max_size=5,
                ssl=ssl_ctx,
                command_timeout=15,
            )
            print("Database pool created.")
        except Exception as e:
            print(f"ERROR creating DB pool: {e}")
            raise

    if not _initialized:
        try:
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
            print("Database tables ready.")
        except Exception as e:
            print(f"ERROR initializing tables: {e}")
            raise

    return pool


async def close_db():
    """Close the connection pool."""
    global pool
    if pool:
        await pool.close()
        pool = None
        print("Database connection closed.")
