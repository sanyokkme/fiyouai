from fastapi import APIRouter, Request, Form, UploadFile, File, Body
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.templating import Jinja2Templates
from config import settings
from database import supabase
from utils import get_now_poland, safe_parse_datetime, clean_to_int
from datetime import timedelta
import uuid

router = APIRouter(tags=["Admin"])
templates = Jinja2Templates(directory="templates")

@router.get("/", response_class=HTMLResponse)
async def admin_login_page(request: Request):
    """Сторінка входу."""
    return templates.TemplateResponse("login.html", {"request": request})

@router.api_route("/admin/dashboard", methods=["GET", "POST"], response_class=HTMLResponse)
async def dashboard(request: Request, username: str = Form(None), password: str = Form(None)):
    """Головна панель статистики."""
    is_auth = request.method == "GET" or (username == settings.ADMIN_USERNAME and password == settings.ADMIN_PASSWORD)
    
    if not is_auth:
        return HTMLResponse("<h1>⛔ Доступ заборонено</h1><a href='/'>Назад</a>", status_code=403)

    try:
        # 1. Список користувачів для email-мапінгу
        users_auth = supabase.auth.admin.list_users()
        users_list = users_auth.users if hasattr(users_auth, 'users') else users_auth
        user_emails = {u.id: u.email for u in users_list}

        # 2. Останні страви
        meals_res = supabase.table("meal_history").select("*").order("created_at", desc=True).limit(15).execute()
        recent_meals = meals_res.data or []
        for meal in recent_meals:
            meal['user_email'] = user_emails.get(meal['user_id'], "Невідомий")

        # 3. Графік активності
        chart_data = []
        try:
            week_ago = (get_now_poland().date() - timedelta(days=7)).isoformat()
            stats_res = supabase.table("meal_history").select("calories, created_at").gte("created_at", week_ago).execute()
            daily_totals = {}
            for entry in stats_res.data:
                day = safe_parse_datetime(entry['created_at']).date().isoformat()
                daily_totals[day] = daily_totals.get(day, 0) + int(entry['calories'] or 0)
            chart_data = [{"day": k, "value": v} for k, v in sorted(daily_totals.items())]
        except:
            chart_data = [{"day": "Немає даних", "value": 0}]

        return templates.TemplateResponse("dashboard.html", {
            "request": request, 
            "users": users_list, 
            "recent_meals": recent_meals,
            "chart_data": chart_data, 
            "docker_url": f"http://{request.client.host}:9000" 
        })
    except Exception as e:
        return HTMLResponse(f"<h1>Помилка: {str(e)}</h1>", status_code=500)

@router.get("/admin/users_list", response_class=HTMLResponse)
async def admin_users_page(request: Request):
    """Сторінка списку всіх користувачів."""
    try:
        profiles_res = supabase.table("user_profiles").select("*").execute()
        
        users_auth = supabase.auth.admin.list_users()
        auth_list = users_auth.users if hasattr(users_auth, 'users') else users_auth
        emails_map = {str(u.id).strip().lower(): u.email for u in auth_list}

        users_data = []
        for p in profiles_res.data:
            p_id = str(p.get('id', '')).strip().lower()
            p['email'] = emails_map.get(p_id, "Немає в Auth")
            users_data.append(p)
            
        return templates.TemplateResponse("users_admin.html", {"request": request, "users": users_data})
    except Exception as e:
        return HTMLResponse(f"Помилка: {e}")

@router.get("/admin/user_details/{user_id}")
async def get_admin_user_details(user_id: str):
    """Детальна історія страв конкретного користувача (JSON)."""
    try:
        res = supabase.table("meal_history").select("*").eq("user_id", user_id).order("created_at", desc=True).limit(20).execute()
        formatted_data = []
        for meal in res.data:
            local_dt = safe_parse_datetime(meal['created_at'])
            meal['display_time'] = local_dt.strftime("%H:%M")
            meal['display_date'] = local_dt.strftime("%d.%m.%Y")
            formatted_data.append(meal)
        return formatted_data
    except Exception as e:
        return {"error": str(e)}

@router.get("/admin/stories", response_class=HTMLResponse)
async def admin_stories_page(request: Request):
    try:
        res = supabase.table('app_stories').select('*').eq('is_active', True).order('sort_order', desc=False).execute()
        stories = res.data if res.data else []
        return templates.TemplateResponse("stories_admin.html", {"request": request, "stories": stories})
    except Exception as e:
        return HTMLResponse(f"<h1>Помилка: {str(e)}</h1>", status_code=500)

@router.post("/admin/add_story")
async def add_story(
    request: Request,
    title: str = Form(...),
    image_url: str = Form(None),
    image_file: UploadFile = File(None)
):
    """Додавання нової сторіз (через URL або Файл)."""
    final_image_url = image_url

    try:
        if image_file and image_file.filename:
            file_ext = image_file.filename.split(".")[-1]
            file_name = f"{uuid.uuid4()}.{file_ext}"
            file_path = f"stories/{file_name}"

            file_content = await image_file.read()

            supabase.storage.from_("stories").upload(
                file_name, 
                file_content, 
                {"content-type": image_file.content_type}
            )

            final_image_url = supabase.storage.from_("stories").get_public_url(file_name)

        if not final_image_url:
             return HTMLResponse("<h1>Помилка: Потрібно вказати посилання або завантажити файл</h1>", status_code=400)
        supabase.table('app_stories').insert({
            "image_url": final_image_url,
            "title": title,
            "is_active": True
        }).execute()

        return RedirectResponse(url="/admin/stories", status_code=303)

    except Exception as e:
        return HTMLResponse(f"<h1>Помилка додавання: {str(e)}</h1>", status_code=500)

@router.post("/admin/delete_story")
async def delete_story(
    request: Request,
    story_id: str = Form(...)
):
    """Видалення сторіз."""
    try:
        supabase.table('app_stories').delete().eq('id', story_id).execute()
        return RedirectResponse(url="/admin/stories", status_code=303)
    except Exception as e:
        return HTMLResponse(f"<h1>Помилка видалення: {str(e)}</h1>", status_code=500)

@router.post("/admin/edit_story")
async def edit_story(
    request: Request,
    story_id: str = Form(...),
    title: str = Form(...),
    image_url: str = Form(None),
    image_file: UploadFile = File(None)
):
    """Редагування існуючої сторіз."""
    final_image_url = image_url

    try:
        if image_file and image_file.filename:
            file_ext = image_file.filename.split(".")[-1]
            file_name = f"{uuid.uuid4()}.{file_ext}"
            file_content = await image_file.read()
            supabase.storage.from_("stories").upload(
                file_name, file_content, {"content-type": image_file.content_type}
            )
            final_image_url = supabase.storage.from_("stories").get_public_url(file_name)

        update_data = {"title": title}
        if final_image_url and final_image_url.strip():
            update_data["image_url"] = final_image_url

        supabase.table('app_stories').update(update_data).eq('id', story_id).execute()
        return RedirectResponse(url="/admin/stories", status_code=303)

    except Exception as e:
        return f"Error editing story: {e}"

@router.post("/admin/reorder_stories")
async def reorder_stories(
    # Отримуємо список ID у новому порядку
    payload: dict = Body(...) 
):
    """Отримує список ID і оновлює їх sort_order."""
    new_order = payload.get("order", [])

    try:
        for index, story_id in enumerate(new_order):
            supabase.table('app_stories').update({'sort_order': index}).eq('id', story_id).execute()

        return {"status": "ok"}
    except Exception as e:
        return {"status": "error", "message": str(e)}