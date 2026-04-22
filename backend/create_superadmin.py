"""
One-time script to create or reset the superadmin account.
Run from the backend/ directory:
    python create_superadmin.py
"""
import asyncio
import ssl
import uuid
import bcrypt
import asyncpg
from dotenv import load_dotenv
import os

load_dotenv()

SUPERADMIN_EMAIL    = "admin@fleet.local"
SUPERADMIN_PASSWORD = "Admin@1234"
SUPERADMIN_NAME     = "Super Admin"


async def main():
    dsn = os.environ["DATABASE_URL"].split("?")[0]
    ssl_ctx = ssl.create_default_context()
    ssl_ctx.check_hostname = False
    ssl_ctx.verify_mode = ssl.CERT_NONE

    conn = await asyncpg.connect(dsn, ssl=ssl_ctx)

    hashed = bcrypt.hashpw(SUPERADMIN_PASSWORD.encode(), bcrypt.gensalt()).decode()

    existing = await conn.fetchval(
        "SELECT id FROM users WHERE role = 'superadmin' AND LOWER(email) = LOWER($1)",
        SUPERADMIN_EMAIL,
    )

    if existing:
        await conn.execute(
            "UPDATE users SET hashed_password = $1 WHERE id = $2",
            hashed, existing,
        )
        print(f"✓ Superadmin password reset for: {SUPERADMIN_EMAIL}")
    else:
        await conn.execute(
            """
            INSERT INTO users (id, tenant_id, role, name, email, phone, hashed_password)
            VALUES ($1, NULL, 'superadmin', $2, LOWER($3), '', $4)
            """,
            uuid.uuid4(), SUPERADMIN_NAME, SUPERADMIN_EMAIL, hashed,
        )
        print(f"✓ Superadmin created: {SUPERADMIN_EMAIL}")

    await conn.close()
    print(f"\nLogin details:")
    print(f"  Workspace : (leave blank  OR type 'superadmin')")
    print(f"  Email     : {SUPERADMIN_EMAIL}")
    print(f"  Password  : {SUPERADMIN_PASSWORD}")


asyncio.run(main())
