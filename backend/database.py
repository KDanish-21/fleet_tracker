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
                    CREATE TABLE IF NOT EXISTS tenants (
                        id UUID PRIMARY KEY,
                        slug VARCHAR(63) UNIQUE NOT NULL,
                        name VARCHAR(255) NOT NULL,
                        currency VARCHAR(3) NOT NULL DEFAULT 'USD',
                        is_active BOOLEAN NOT NULL DEFAULT TRUE,
                        max_devices INT NOT NULL DEFAULT 4,
                        created_at TIMESTAMPTZ DEFAULT NOW()
                    );
                """)
                await conn.execute("""
                    ALTER TABLE tenants
                    ADD COLUMN IF NOT EXISTS max_devices INT NOT NULL DEFAULT 4;
                """)
                await conn.execute("""
                    CREATE TABLE IF NOT EXISTS users (
                        id UUID PRIMARY KEY,
                        tenant_id UUID NOT NULL REFERENCES tenants(id),
                        role VARCHAR(32) NOT NULL DEFAULT 'user',
                        name VARCHAR(255) NOT NULL,
                        email VARCHAR(255) NOT NULL,
                        phone VARCHAR(50) DEFAULT '',
                        hashed_password VARCHAR(255) NOT NULL,
                        is_active BOOLEAN NOT NULL DEFAULT TRUE,
                        created_at TIMESTAMPTZ DEFAULT NOW()
                    );
                """)
                await conn.execute("""
                    CREATE UNIQUE INDEX IF NOT EXISTS users_tenant_email_key
                        ON users (tenant_id, lower(email));
                """)
                await conn.execute("""
                    CREATE TABLE IF NOT EXISTS tenant_devices (
                        tenant_id UUID REFERENCES tenants(id) ON DELETE CASCADE,
                        device_id VARCHAR(128) NOT NULL,
                        device_name VARCHAR(255) DEFAULT '',
                        created_at TIMESTAMPTZ DEFAULT NOW(),
                        PRIMARY KEY (tenant_id, device_id)
                    );
                """)
                await conn.execute("""
                    CREATE INDEX IF NOT EXISTS tenant_devices_device_id_idx
                        ON tenant_devices (device_id);
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
