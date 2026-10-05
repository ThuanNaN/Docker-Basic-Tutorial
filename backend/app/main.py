from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI, HTTPException, Request, Response
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from sqlalchemy import select, text
from sqlalchemy.exc import OperationalError
from sqlalchemy.orm import Session

from app.db import Base, engine, get_session
from app.models import Book
from app.schemas import BookIn, BookOut


@asynccontextmanager
async def lifespan(_: FastAPI):
    # Compose starts this service only after the db healthcheck passes.
    Base.metadata.create_all(engine)
    yield


app = FastAPI(title="VLAI Bookstore API", lifespan=lifespan)


@app.exception_handler(RequestValidationError)
async def invalid_request(_: Request, exc: RequestValidationError):
    # FastAPI's default 422 body echoes the rejected input; for Infinity that value cannot be
    # rendered as JSON and turns the 422 into a 500. Keep only where and why it was rejected.
    errors = [{"loc": e["loc"], "msg": e["msg"], "type": e["type"]} for e in exc.errors()]
    return JSONResponse(status_code=422, content={"detail": errors})


@app.exception_handler(OperationalError)
async def database_unavailable(_: Request, __: OperationalError):
    # Any route that cannot reach the database answers 503, not a bare 500.
    return JSONResponse(status_code=503, content={"detail": "database unavailable"})


def _get_or_404(session: Session, book_id: int) -> Book:
    book = session.get(Book, book_id)
    if book is None:
        raise HTTPException(status_code=404, detail="book not found")
    return book


@app.get("/health")
def health(session: Session = Depends(get_session)):
    try:
        session.execute(text("SELECT 1"))
    except Exception:
        raise HTTPException(status_code=503, detail="database unavailable")
    return {"status": "ok"}


@app.get("/books", response_model=list[BookOut])
def list_books(session: Session = Depends(get_session)):
    return session.scalars(select(Book).order_by(Book.id)).all()


@app.post("/books", response_model=BookOut, status_code=201)
def create_book(payload: BookIn, session: Session = Depends(get_session)):
    book = Book(**payload.model_dump())
    session.add(book)
    session.commit()
    session.refresh(book)
    return book


@app.get("/books/{book_id}", response_model=BookOut)
def get_book(book_id: int, session: Session = Depends(get_session)):
    return _get_or_404(session, book_id)


@app.put("/books/{book_id}", response_model=BookOut)
def update_book(book_id: int, payload: BookIn, session: Session = Depends(get_session)):
    book = _get_or_404(session, book_id)
    for field, value in payload.model_dump().items():
        setattr(book, field, value)
    session.commit()
    session.refresh(book)
    return book


@app.delete("/books/{book_id}", status_code=204)
def delete_book(book_id: int, session: Session = Depends(get_session)):
    book = _get_or_404(session, book_id)
    session.delete(book)
    session.commit()
    return Response(status_code=204)
