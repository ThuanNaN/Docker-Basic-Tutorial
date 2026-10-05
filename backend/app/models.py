from sqlalchemy import Float, String
from sqlalchemy.orm import Mapped, mapped_column

from app.db import Base


class Book(Base):
    __tablename__ = "books"

    id: Mapped[int] = mapped_column(primary_key=True)
    title: Mapped[str] = mapped_column(String(200))
    author: Mapped[str] = mapped_column(String(120))
    price: Mapped[float] = mapped_column(Float)
    year: Mapped[int | None] = mapped_column(default=None)
