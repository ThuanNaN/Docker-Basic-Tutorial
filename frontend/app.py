import os

import gradio as gr
import httpx

API_URL = os.environ.get("API_URL", "http://backend:8000")
COLUMNS = ["id", "title", "author", "price", "year"]


def _request(method: str, path: str, **kwargs) -> httpx.Response:
    """Call the backend; turn every failure into a message the UI can show."""
    try:
        response = httpx.request(method, f"{API_URL}{path}", timeout=5.0, **kwargs)
        response.raise_for_status()
        return response
    except httpx.HTTPStatusError as exc:
        raise gr.Error(f"Backend trả lỗi {exc.response.status_code}: {exc.response.text}")
    except httpx.HTTPError as exc:
        raise gr.Error(f"Không kết nối được backend ({API_URL}): {exc}")


def load_books():
    books = _request("GET", "/books").json()
    return [[book[column] for column in COLUMNS] for book in books]


def save_book(book_id, title, author, price, year):
    payload = {
        "title": title,
        "author": author,
        "price": price,
        "year": int(year) if year else None,
    }
    if book_id:
        _request("PUT", f"/books/{int(book_id)}", json=payload)
        message = f"Đã cập nhật sách #{int(book_id)}"
    else:
        created = _request("POST", "/books", json=payload).json()
        message = f"Đã thêm sách #{created['id']}"
    return load_books(), message


def delete_book(book_id):
    if not book_id:
        raise gr.Error("Chọn một dòng trong bảng (hoặc nhập ID) trước khi xóa.")
    _request("DELETE", f"/books/{int(book_id)}")
    return load_books(), f"Đã xóa sách #{int(book_id)}"


def clear_form():
    return None, "", "", None, None


def _blank(value) -> bool:
    return value is None or value == "" or value != value  # None, "" or NaN (NaN != NaN)


def pick_row(table, evt: gr.SelectData):
    index = evt.index[0]
    if table is None or index >= len(table):
        return clear_form()
    row = table.iloc[index]
    if _blank(row["id"]):  # the placeholder row Gradio shows for an empty table
        return clear_form()
    year = None if _blank(row["year"]) else int(row["year"])
    return int(row["id"]), row["title"], row["author"], float(row["price"]), year


with gr.Blocks(title="VLAI Bookstore") as demo:
    gr.Markdown("# VLAI Bookstore\nGradio (frontend) → FastAPI (backend) → PostgreSQL (database)")
    # value=[] on purpose: a callable value would call the backend while this module is imported,
    # so the container would crash at startup whenever the backend is not up yet.
    table = gr.Dataframe(value=[], headers=COLUMNS, interactive=False, label="Danh sách sách")
    status = gr.Markdown()
    with gr.Row():
        book_id = gr.Number(label="ID (để trống = thêm mới)", precision=0)
        title = gr.Textbox(label="Tên sách")
        author = gr.Textbox(label="Tác giả")
        price = gr.Number(label="Giá")
        year = gr.Number(label="Năm xuất bản", precision=0)
    with gr.Row():
        save_btn = gr.Button("Lưu", variant="primary")
        delete_btn = gr.Button("Xóa", variant="stop")
        clear_btn = gr.Button("Làm mới form")
        reload_btn = gr.Button("Tải lại danh sách")

    form = [book_id, title, author, price, year]
    demo.load(load_books, None, table)  # runs when a browser opens the page, not at import
    table.select(pick_row, table, form)
    save_btn.click(save_book, form, [table, status])
    delete_btn.click(delete_book, book_id, [table, status])
    clear_btn.click(clear_form, None, form)
    reload_btn.click(load_books, None, table)

if __name__ == "__main__":
    demo.launch(server_name="0.0.0.0", server_port=7860)
