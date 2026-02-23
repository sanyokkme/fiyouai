import logging
import pytz
from datetime import datetime
from contextlib import asynccontextmanager
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from rich.logging import RichHandler
from rich.console import Console
from banner import *
from dotenv import load_dotenv

load_dotenv()

# Імпорт роутерів
from routers import auth, profile, tracking, ai, admin, weight

# НАЛАШТУВАННЯ
POLAND_TZ = pytz.timezone('Europe/Warsaw')
console = Console()

def setup_logging():

    silent_libraries = [
        "uvicorn", "uvicorn.access", "uvicorn.error", "uvicorn.asgi",
        "watchfiles", "httpcore", "httpx", 
        "supabase", "postgrest", "gotrue"
    ]
    
    for lib in silent_libraries:
        logger = logging.getLogger(lib)
        logger.setLevel(logging.CRITICAL)
        logger.propagate = False

    logging.basicConfig(
        level=logging.INFO,
        format="%(message)s",
        datefmt="[%X]",
        handlers=[RichHandler(console=console, show_path=False, markup=True)]
    )

setup_logging()
logger = logging.getLogger("nutritionai-backend")

# Дії при старті/перезапуску
@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    При старті (або перезапуску через reload) виводить лише 
    коротке повідомлення з часом.
    Великий банер винесено в окремий скрипт (banner.py).
    """
    current_time = datetime.now(POLAND_TZ).strftime("%H:%M:%S")
    console.print(f"[bold dim green]Backend reloaded ({current_time})[/]")

    yield

# ІНІЦІАЛІЗАЦІЯ APP
app = FastAPI(
    title="NutritionAI Backend API", 
    version="1.0.0",
    lifespan=lifespan
)

# Глобальний обробник помилок
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    error_msg = str(exc)
    logger.error(f"[bold red]UNHANDLED ERROR:[/bold red] {error_msg}")
    return JSONResponse(status_code=500, content={"status": "error", "message": error_msg})

# CORS
app.add_middleware(
    CORSMiddleware, 
    allow_origins=["*"], 
    allow_credentials=True, 
    allow_methods=["*"], 
    allow_headers=["*"]
)

# Логування запитів
@app.middleware("http")
async def log_requests(request: Request, call_next):
    response = await call_next(request)
    color = "green" if response.status_code < 400 else "red"

    console.print(f"""
[bold green]{request.method}[/] -> [white]{request.url.path}[/]
┗━ [status: [{color}]{response.status_code}[/]] for [bold]{request.url.path}[/]
    """)
    
    return response

# ПІДКЛЮЧЕННЯ РОУТЕРІВ
app.include_router(auth.router)
app.include_router(profile.router)
app.include_router(tracking.router)
app.include_router(ai.router)
app.include_router(admin.router)
app.include_router(weight.router)