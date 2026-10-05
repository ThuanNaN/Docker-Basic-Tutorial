from pydantic import BaseModel, ConfigDict, Field, field_validator


class BookIn(BaseModel):
    title: str = Field(min_length=1, max_length=200)
    author: str = Field(min_length=1, max_length=120)
    price: float = Field(ge=0, allow_inf_nan=False)
    year: int | None = Field(default=None, ge=0, le=2100)

    @field_validator("title", "author")
    @classmethod
    def reject_nul(cls, value: str) -> str:
        if "\x00" in value:
            raise ValueError("must not contain NUL characters")
        return value


class BookOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    title: str
    author: str
    price: float
    year: int | None = None
