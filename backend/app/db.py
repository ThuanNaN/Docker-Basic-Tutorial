import os

from sqlalchemy import create_engine
from sqlalchemy.orm import DeclarativeBase, sessionmaker

# Assembled by compose from .env, e.g. postgresql+psycopg://user:pass@db:5432/bookstore
DATABASE_URL = os.environ["DATABASE_URL"]

# pool_pre_ping: a connection broken by a db restart is replaced instead of raising.
engine = create_engine(DATABASE_URL, pool_pre_ping=True)
SessionLocal = sessionmaker(bind=engine, autoflush=False)


class Base(DeclarativeBase):
    pass


def get_session():
    with SessionLocal() as session:
        yield session
